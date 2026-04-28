import Vapor
import Argon2Swift
import HRW

final class VCManagedUserForm: ManagedUserForm {
    init(user: User?, editPath: String?, error: String?) throws {
        try super.init()
        let isNewUser = user == nil
        title.children.removeAll()
        title.addChild(HTMLText(content: isNewUser ? "Add User" : "Edit User"))
        submit_button.children.removeAll()
        submit_button.addChild(HTMLText(content: isNewUser ? "Create User" : "Update User"))
        if let user {
            rootNode.action = URL(string: editPath ?? "/user/edit_all/\(user.id.description)/edit")
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
