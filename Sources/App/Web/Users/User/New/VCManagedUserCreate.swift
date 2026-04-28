import Vapor
import Argon2Swift

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
            id: SmallUid(),
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

    return req.redirect(to: "/user/edit_all/\(newUser.id.description)/edit", redirectType: .normal)
}
