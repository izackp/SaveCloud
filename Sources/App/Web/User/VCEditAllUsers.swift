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

private func shortManagedUserDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
}

private func fullManagedUserDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

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
        username.addChild(HTMLText(content: user.username))
        username_link.href = URL(string: "/users/\(user.id.uuidString)")
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        created_at.addChild(HTMLText(content: shortManagedUserDateText(user.createdAt)))
        created_at.globalAttributes[.title] = fullManagedUserDateText(user.createdAt)
        updated_at.addChild(HTMLText(content: shortManagedUserDateText(user.updatedAt)))
        updated_at.globalAttributes[.title] = fullManagedUserDateText(user.updatedAt)
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
    init(user: User?, editPath: String?, error: String?) throws {
        try super.init()
        let isNewUser = user == nil
        title.children.removeAll()
        title.addChild(HTMLText(content: isNewUser ? "Add User" : "Edit User"))
        submit_button.children.removeAll()
        submit_button.addChild(HTMLText(content: isNewUser ? "Create User" : "Update User"))
        if let user {
            rootNode.action = URL(string: editPath ?? "/user/edit_all/\(user.id.uuidString)/edit")
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
    init(session: AuthSession, user: User?, editPath: String?, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        form_container.addChild(try VCManagedUserForm(user: user, editPath: editPath, error: error).rootNode)
    }
}

final class VCManagedUserProfileGridItem: ProfileGridItem {
    init(user: User, profile: UserProfile) throws {
        try super.init()
        profile_link.href = URL(string: "/users/\(user.id.uuidString)/profiles/\(profile.id.description)/games")
        let profileId = profile.id.description
        profile_avatar_container.addChild(HTMLText(content: #"<svg width="80" height="80" data-jdenticon-value="\#(profileId)"></svg>"#))
        name.addChild(HTMLText(content: profile.name))
    }
}

final class VCManagedUserDetailPage: ManagedUserDetailPage {
    init(session: AuthSession, user: User, profiles: [UserProfile], error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: session.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        title.addChild(HTMLText(content: user.username))
        edit_link.href = URL(string: "/users/\(user.id.uuidString)/edit")
        username.addChild(HTMLText(content: user.username))
        email.addChild(HTMLText(content: user.email ?? ""))
        is_admin.addChild(HTMLText(content: user.isAdmin ? "Yes" : "No"))
        user_id.addChild(HTMLText(content: user.id.uuidString))
        created_at.addChild(HTMLText(content: String(describing: user.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: user.updatedAt)))
        if profiles.isEmpty {
            empty_profiles_text.globalAttributes[.style] = ""
        } else {
            for profile in profiles {
                profiles_container.children.append(try VCManagedUserProfileGridItem(user: user, profile: profile).rootNode)
            }
        }
        back_link.href = URL(string: "/user/edit_all")
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

private func managedUserEditPath(for req: Request, user: User?) -> String? {
    guard let user else {
        return nil
    }
    if req.url.path == "/users/\(user.id.uuidString)/edit" {
        return "/users/\(user.id.uuidString)/edit"
    }
    return "/user/edit_all/\(user.id.uuidString)/edit"
}

private func managedUserFormError(_ session: AuthSession, req: Request, user: User?, error: String) throws -> Response {
    try VCManagedUserPage(session: session, user: user, editPath: managedUserEditPath(for: req, user: user), error: error).rootNode.response()
}

private func fetchManagedUser(req: Request, pool: DatabasePool) async throws -> User? {
    guard let userId: UUID = req.parameters.get("managed_user_id") ?? req.parameters.get("user_id") else {
        return nil
    }
    return try await pool.read { db in
        try User.filter(id: userId).fetchOne(db)
    }
}

private func fetchProfiles(for user: User, pool: DatabasePool) async throws -> [UserProfile] {
    try await pool.read { db in
        try UserProfile
            .filter(UserProfile.user_id == user.id)
            .order(UserProfile.name.asc)
            .fetchAll(db)
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
    return try VCManagedUserPage(session: session, user: nil, editPath: nil, error: nil).rootNode.response()
}

@Sendable func createManagedUser(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let contents = try req.content.decode(ManagedUserRequest.self)
    if let error = contents.validate(isNewUser: true) {
        return try managedUserFormError(session, req: req, user: nil, error: error)
    }

    let pool = DBShared.pool()
    if let error = try await ensureUniqueManagedUserFields(pool: pool, username: contents.username, email: contents.email, excluding: nil) {
        return try managedUserFormError(session, req: req, user: nil, error: error)
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
    return try VCManagedUserPage(session: session, user: user, editPath: managedUserEditPath(for: req, user: user), error: nil).rootNode.response()
}

@Sendable func managedUserPageByUserId(req: Request) async throws -> Response {
    guard let session = try await adminSession(for: req) else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let user = try await fetchManagedUser(req: req, pool: pool) else {
        return try VCEditAllUsersPage(session: session, users: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "User not found.").rootNode.response()
    }
    let profiles = try await fetchProfiles(for: user, pool: pool)
    return try VCManagedUserDetailPage(session: session, user: user, profiles: profiles, error: nil).rootNode.response()
}

@Sendable func editManagedUserPageByUserId(req: Request) async throws -> Response {
    try await editManagedUserPage(req: req)
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
        return try managedUserFormError(session, req: req, user: user, error: error)
    }
    if let error = try await ensureUniqueManagedUserFields(pool: pool, username: contents.username, email: contents.email, excluding: user.id) {
        return try managedUserFormError(session, req: req, user: user, error: error)
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

    return try VCManagedUserPage(session: session, user: updatedUser, editPath: managedUserEditPath(for: req, user: updatedUser), error: nil).rootNode.response()
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
        let response = req.redirect(to: "/", redirectType: .normal)
        clearBrowserSessionCookie(on: response)
        return response
    }

    return req.redirect(to: "/user/edit_all", redirectType: .normal)
}

struct ManagedSessionRequest: Content {
    let user_id: String
    let refresh_token: String?
    let device_name: String?
    let location: String?
    let ip_address: String
    let is_admin: String?
    let expires_at: String

    var isAdmin: Bool {
        is_admin != nil
    }

    func validate() -> String? {
        if UUID(uuidString: user_id) == nil {
            return "User ID is invalid."
        }
        if let refresh_token, !refresh_token.isEmpty && UUID(uuidString: refresh_token) == nil {
            return "Refresh token is invalid."
        }
        if ip_address.isEmpty {
            return "IP Address is empty."
        }
        if ISO8601DateFormatter().date(from: expires_at) == nil {
            return "Expires At must be ISO-8601."
        }
        return nil
    }
}

struct SessionPageContext {
    let viewer: AuthSession
    let targetUserId: UUID?
    let basePath: String
    let canEdit: Bool

    func canDelete(_ session: AuthSession) -> Bool {
        viewer.isAdmin || viewer.user == session.user
    }

    func isCurrent(_ session: AuthSession) -> Bool {
        viewer.id == session.id
    }
}

final class VCEditSessionsTableRow: EditSessionsTableRow {
    init(session: AuthSession, context: SessionPageContext) throws {
        try super.init()
        session_id.addChild(HTMLText(content: session.id.uuidString))
        if context.isCurrent(session) {
            session_id.addChild(HTMLText(content: " (Current)"))
            rootNode.globalAttributes[.class_] = "is-current-session"
        }
        user_id.addChild(HTMLText(content: session.user.uuidString))
        refresh_token.addChild(HTMLText(content: session.refreshToken?.uuidString ?? ""))
        device_name.addChild(HTMLText(content: session.deviceName ?? ""))
        location.addChild(HTMLText(content: session.location ?? ""))
        ip_address.addChild(HTMLText(content: session.ipAddress))
        is_admin.addChild(HTMLText(content: session.isAdmin ? "Yes" : "No"))
        expires_at.addChild(HTMLText(content: String(describing: session.expiresAt)))
        if context.canEdit {
            edit_link.href = URL(string: "\(context.basePath)/\(session.id.uuidString)/edit")
        } else {
            edit_link.globalAttributes[.style] = "display:none"
        }
        if context.canDelete(session) {
            delete_link.href = URL(string: "\(context.basePath)/\(session.id.uuidString)/delete")
        } else {
            delete_link.globalAttributes[.style] = "display:none"
        }
    }
}

final class VCEditSessionsPage: EditSessionsPage {
    init(context: SessionPageContext, sessions: [AuthSession], pageInfo: ManagedUserPageInfo, hasNextPage: Bool, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        if let error {
            p_error.addChild(HTMLText(content: error))
            p_error.globalAttributes[.style] = ""
        }
        for item in sessions {
            table.children.append(try VCEditSessionsTableRow(session: item, context: context).rootNode)
        }
        page_text.addChild(HTMLText(content: "Page \(pageInfo.page + 1)"))
        if pageInfo.page > 0 {
            prev_link.href = URL(string: "\(context.basePath)?\(pageInfo.queryString(page: pageInfo.page - 1))")
            prev_link.globalAttributes[.style] = ""
        }
        if hasNextPage {
            next_link.href = URL(string: "\(context.basePath)?\(pageInfo.queryString(page: pageInfo.page + 1))")
            next_link.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedSessionForm: ManagedSessionForm {
    init(session: AuthSession, basePath: String, error: String?) throws {
        try super.init()
        rootNode.action = URL(string: "\(basePath)/\(session.id.uuidString)/edit")
        session_id.addChild(HTMLText(content: session.id.uuidString))
        user_id.value = session.user.uuidString
        refresh_token.value = session.refreshToken?.uuidString ?? ""
        device_name.value = session.deviceName ?? ""
        location.value = session.location ?? ""
        ip_address.value = session.ipAddress
        is_admin.checked = session.isAdmin
        expires_at.value = ISO8601DateFormatter().string(from: session.expiresAt)
        created_at.addChild(HTMLText(content: String(describing: session.createdAt)))
        updated_at.addChild(HTMLText(content: String(describing: session.updatedAt)))
        if let error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

final class VCManagedSessionPage: ManagedSessionPage {
    init(context: SessionPageContext, managedSession: AuthSession, error: String?) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        form_container.addChild(try VCManagedSessionForm(session: managedSession, basePath: context.basePath, error: error).rootNode)
    }
}

final class VCDeleteManagedSessionPage: DeleteManagedSessionPage {
    init(context: SessionPageContext, managedSession: AuthSession) throws {
        try super.init()
        nav_bar.addChild(try VCNavBar(isAdmin: context.viewer.isAdmin).rootNode)
        session_id.addChild(HTMLText(content: managedSession.id.uuidString))
        user_id.addChild(HTMLText(content: managedSession.user.uuidString))
        device_name.addChild(HTMLText(content: managedSession.deviceName ?? ""))
        ip_address.addChild(HTMLText(content: managedSession.ipAddress))
        expires_at.addChild(HTMLText(content: String(describing: managedSession.expiresAt)))
        delete_form.action = URL(string: "\(context.basePath)/\(managedSession.id.uuidString)/delete")
        cancel_link.href = URL(string: context.basePath)
    }
}

private func managedSessionFormError(_ context: SessionPageContext, managedSession: AuthSession, error: String) throws -> Response {
    try VCManagedSessionPage(context: context, managedSession: managedSession, error: error).rootNode.response()
}

private func unauthorizedResponse() throws -> Response {
    try VCWelcomePage(users: [], error: "Unauthorized").rootNode.response()
}

private func sessionPageContext(for req: Request) async throws -> SessionPageContext? {
    guard let viewer = try await req.fetchSession() else {
        return nil
    }

    if req.url.path == "/sessions" || req.url.path.hasPrefix("/sessions/") {
        guard viewer.isAdmin else {
            return nil
        }
        return SessionPageContext(
            viewer: viewer,
            targetUserId: nil,
            basePath: "/sessions",
            canEdit: true
        )
    }

    if let userId: UUID = req.parameters.get("user_id") {
        guard viewer.isAdmin || viewer.user == userId else {
            return nil
        }
        return SessionPageContext(
            viewer: viewer,
            targetUserId: userId,
            basePath: "/users/\(userId.uuidString)/sessions",
            canEdit: viewer.isAdmin
        )
    }

    return SessionPageContext(
        viewer: viewer,
        targetUserId: viewer.user,
        basePath: "/user/sessions",
        canEdit: viewer.isAdmin
    )
}

private func fetchManagedSession(req: Request, pool: DatabasePool, targetUserId: UUID?) async throws -> AuthSession? {
    guard let sessionId: UUID = req.parameters.get("managed_session_id") else {
        return nil
    }
    return try await pool.read { db in
        var request = AuthSession.filter(id: sessionId)
        if let targetUserId {
            request = request.filter(AuthSession.user == targetUserId)
        }
        return try request.fetchOne(db)
    }
}

@Sendable func editAllSessions(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pageInfo = ManagedUserPageInfo(req: req)
    let pool = DBShared.pool()
    let sessions = try await pool.read { db in
        var request = AuthSession.order(AuthSession.created_at.desc)
        if let targetUserId = context.targetUserId {
            request = request.filter(AuthSession.user == targetUserId)
        }
        return try request
            .limit(Int(pageInfo.perPage) + 1, offset: Int(pageInfo.page * pageInfo.perPage))
            .fetchAll(db)
    }
    let hasNextPage = sessions.count > Int(pageInfo.perPage)
    let pageSessions = Array(sessions.prefix(Int(pageInfo.perPage)))
    return try VCEditSessionsPage(context: context, sessions: pageSessions, pageInfo: pageInfo, hasNextPage: hasNextPage, error: nil).rootNode.response()
}

@Sendable func editManagedSessionPage(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req), context.canEdit else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    return try VCManagedSessionPage(context: context, managedSession: managedSession, error: nil).rootNode.response()
}

@Sendable func updateManagedSession(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req), context.canEdit else {
        return try adminAccessDeniedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }

    let contents = try req.content.decode(ManagedSessionRequest.self)
    if let error = contents.validate() {
        return try managedSessionFormError(context, managedSession: managedSession, error: error)
    }

    let updatedSession = try await pool.write { db in
        var updated = managedSession
        updated.user = UUID(uuidString: contents.user_id)!
        updated.refreshToken = contents.refresh_token?.isEmpty == false ? UUID(uuidString: contents.refresh_token!) : nil
        updated.deviceName = contents.device_name?.isEmpty == false ? contents.device_name : nil
        updated.location = contents.location?.isEmpty == false ? contents.location : nil
        updated.ipAddress = contents.ip_address
        updated.isAdmin = contents.isAdmin
        updated.expiresAt = ISO8601DateFormatter().date(from: contents.expires_at)!
        updated.updatedAt = Date()
        try updated.update(db)
        return updated
    }

    return try VCManagedSessionPage(context: context, managedSession: updatedSession, error: nil).rootNode.response()
}

@Sendable func deleteManagedSessionPage(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    guard context.canDelete(managedSession) else {
        return try unauthorizedResponse()
    }
    return try VCDeleteManagedSessionPage(context: context, managedSession: managedSession).rootNode.response()
}

@Sendable func deleteManagedSession(req: Request) async throws -> Response {
    guard let context = try await sessionPageContext(for: req) else {
        return try unauthorizedResponse()
    }

    let pool = DBShared.pool()
    guard let managedSession = try await fetchManagedSession(req: req, pool: pool, targetUserId: context.targetUserId) else {
        return try VCEditSessionsPage(context: context, sessions: [], pageInfo: ManagedUserPageInfo(req: req), hasNextPage: false, error: "Session not found.").rootNode.response()
    }
    guard context.canDelete(managedSession) else {
        return try unauthorizedResponse()
    }

    _ = try await pool.write { db in
        try AuthSession.filter(id: managedSession.id).deleteAll(db)
    }

    if context.viewer.id == managedSession.id {
        let response = req.redirect(to: "/", redirectType: .normal)
        clearBrowserSessionCookie(on: response)
        return response
    }

    return req.redirect(to: context.basePath, redirectType: .normal)
}
