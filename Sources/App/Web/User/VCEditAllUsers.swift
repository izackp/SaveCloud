//
//  VCEditAllUsers.swift
//
//
//  Created by OpenAI on 4/24/26.
//

import Vapor
import Argon2Swift
import HRW
import GRDB

struct ManagedUserPageInfo {
    let page: UInt
    let perPage: UInt

    init(req: Request) {
        page = (try? req.query.get(UInt.self, at: "page")) ?? 0
        let requestedPerPage = (try? req.query.get(UInt.self, at: "per_page")) ?? 20
        perPage = min(max(requestedPerPage, 1), 100)
    }

    func queryString(page: UInt) -> String {
        "page=\(page)&per_page=\(perPage)"
    }
}

struct ManagedUserRequest: Content {
    let username: String
    let email: String
    let password: String?
    let is_admin: String?

    var isAdmin: Bool {
        is_admin != nil
    }

    func validate(isNewUser: Bool) -> String? {
        if username.isEmpty {
            return "Username is empty."
        }
        if email.isEmpty {
            return "Email is empty."
        }
        if isNewUser && (password?.isEmpty != false) {
            return "Password is empty."
        }
        return nil
    }
}

final class VCEditAllUsersTableRow: EditAllUsersTableRow {
    init(user: User) throws {
        try super.init()
        user_id.addChild(HTMLText(content: user.id.uuidString))
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
        edit_link.href = URL(string: "/user/edit_all/\(user.id.uuidString)/edit")
        delete_link.href = URL(string: "/user/edit_all/\(user.id.uuidString)/delete")
    }
}

final class VCEditAllUsersPage: EditAllUsersPage {
    init(session: AuthSession, users: [User], pageInfo: ManagedUserPageInfo, hasNextPage: Bool, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for user in users {
            table.children.append(try VCEditAllUsersTableRow(user: user).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(pageInfo.page + 1)"))
        if pageInfo.page > 0 {
            prev_link.href = URL(string: "/user/edit_all?\(pageInfo.queryString(page: pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "/user/edit_all?\(pageInfo.queryString(page: pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedUserForm: ManagedUserForm {
    init(user: User?, error: String?) throws {
        try super.init()
        let isNewUser = user == nil
        title.children.removeAll()
        title.addChild(HTMLText(content: isNewUser ? "Add User" : "Edit User"))
        submit_button.children.removeAll()
        submit_button.addChild(HTMLText(content: isNewUser ? "Create User" : "Update User"))
        if let user {
            rootNode.action = URL(string: "/user/edit_all/\(user.id.uuidString)/edit")
            username.value = user.username
            email.value = user.email ?? ""
            if user.isAdmin {
                is_admin.checked = true
            }
            created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
            updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
            created_container.globalAttributes[.style] = ""
            updated_container.globalAttributes[.style] = ""
            password.placeholder = "Leave blank to keep current password"
        } else {
            rootNode.action = URL(string: "/user/edit_all/new")
        }
        if let error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedUserPage: ManagedUserPage {
    init(session: AuthSession, user: User?, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        form_container.addChild(try VCManagedUserForm(user: user, error: error).rootNode)
    }
}

final class VCDeleteManagedUserPage: DeleteManagedUserPage {
    init(session: AuthSession, user: User) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        user_id.addChild(HTMLText(content: user.id.uuidString))
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        delete_form.action = URL(string: "/user/edit_all/\(user.id.uuidString)/delete")
        cancel_link.href = URL(string: "/user/edit_all")
    }
}

private func adminSession(for req: Request) async throws -> AuthSession? {
    guard let session = try await req.fetchSession(), session.isAdmin else {
        return nil
    }
    return session
}

private func adminAccessDeniedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Admin access required.").rootNode.response()
}

private func managedUserFormError(_ session: AuthSession, user: User?, error: String) throws -> Response {
    try VCManagedUserPage(session: session, user: user, error: error).rootNode.response()
}

private func fetchManagedUser(req: Request, pool: DatabasePool) async throws -> User? {
    guard let userId: UUID = req.parameters.get("managed_user_id") else {
        return nil
    }
    return try await pool.read { db in
        try User.filter(id: userId).fetchOne(db)
    }
}

private func ensureUniqueManagedUserFields(pool: DatabasePool, username: String, email: String, excluding userId: UUID?) async throws -> String? {
    let duplicateUsername = try await pool.read { db in
        var request = User.filter(User.username == username)
        if let userId {
            request = request.filter(User.id != userId)
        }
        return try request.fetchCount(db) > 0
    }
    if duplicateUsername {
        return "Username \(username) already exists."
    }

    let duplicateEmail = try await pool.read { db in
        var request = User.filter(User.email == email)
        if let userId {
            request = request.filter(User.id != userId)
        }
        return try request.fetchCount(db) > 0
    }
    if duplicateEmail {
        return "Email \(email) is already in use."
    }

    return nil
}

@Sendable func editAllUsers(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pageInfo = ManagedUserPageInfo(req: req)
    let pool = DBShared.pool()
    let users = try await pool.read { db in
        try User
            .order(User.username.asc)
            .limit(Int(pageInfo.perPage) + 1, offset: Int(pageInfo.page * pageInfo.perPage))
            .fetchAll(db)
    }
    let hasNextPage = users.count > Int(pageInfo.perPage)
    let pageUsers = Array(users.prefix(Int(pageInfo.perPage)))
    return try VCEditAllUsersPage(session: session, users: pageUsers, pageInfo: pageInfo, hasNextPage: hasNextPage, error: nil).rootNode.response()
}

@Sendable func newManagedUserPage(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }
    return try VCManagedUserPage(session: session, user: nil, error: nil).rootNode.response()
}

@Sendable func createManagedUser(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let contents = try req.content.decode(ManagedUserRequest.self)
    if let error = contents.validate(isNewUser: true) {
        return try managedUserFormError(session, user: nil, error: error)
    }

    let pool = DBShared.pool()
    if let error = try await ensureUniqueManagedUserFields(pool: pool, username: contents.username, email: contents.email, excluding: nil) {
        return try managedUserFormError(session, user: nil, error: error)
    }

    let password = contents.password ?? ""
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: password, salt: salt).encodedString()
    let date = Date()
    let newUser = try await pool.write { db in
        var user = User(
            id: UUID(),
            username: contents.username,
            email: contents.email,
            passwordHash: passwordHash,
            isAdmin: contents.isAdmin,
            createdAt: date,
            updatedAt: date
        )
        try user.insert(db)
        return user
    }

    return req.redirect(to: "/user/edit_all/\(newUser.id.uuidString)/edit", redirectType: .normal)
}

@Sendable func editManagedUserPage(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }
    return try VCManagedUserPage(session: session, user: user, error: nil).rootNode.response()
}

@Sendable func updateManagedUser(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }

    let contents = try req.content.decode(ManagedUserRequest.self)
    if let error = contents.validate(isNewUser: false) {
        return try managedUserFormError(session, user: user, error: error)
    }
    if let error = try await ensureUniqueManagedUserFields(pool: pool, username: contents.username, email: contents.email, excluding: user.id) {
        return try managedUserFormError(session, user: user, error: error)
    }

    let newPasswordHash: String?
    if let password = contents.password, !password.isEmpty {
        let salt = Salt.newSalt()
        newPasswordHash = try Argon2Swift.hashPasswordString(password: password, salt: salt).encodedString()
    } else {
        newPasswordHash = user.passwordHash
    }

    let updatedUser = try await pool.write { db in
        var matchingUser = user
        matchingUser.username = contents.username
        matchingUser.email = contents.email
        matchingUser.isAdmin = contents.isAdmin
        matchingUser.passwordHash = newPasswordHash
        matchingUser.updatedAt = Date()
        try matchingUser.update(db)
        return matchingUser
    }

    return try VCManagedUserPage(session: session, user: updatedUser, error: nil).rootNode.response()
}

@Sendable func deleteManagedUserPage(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }
    return try VCDeleteManagedUserPage(session: session, user: user).rootNode.response()
}

@Sendable func deleteManagedUser(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }

    try await pool.write { db in
        try AuthSession.filter(AuthSession.user == user.id).deleteAll(db)
        try User.filter(id: user.id).deleteAll(db)
    }

    if session.user == user.id {
        req.session.unauthenticate(AuthSession.self)
        return req.redirect(to: "/", redirectType: .normal)
    }

    return req.redirect(to: "/user/edit_all", redirectType: .normal)
}
