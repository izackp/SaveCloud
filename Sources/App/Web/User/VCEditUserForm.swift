//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Argon2Swift
import HRW

struct EditUserRequest: Content {
    let username: String
    let email: String
    let password: String
    
    func validate() -> String? {
        if (username.isEmpty) {
            return "Username is empty."
        }
        if (email.isEmpty) {
            return "Email is empty."
        }
        if (password.isEmpty) {
            return "Password is empty."
        }
        
        return nil
    }
}

class VCEditUserForm : EditUserForm {

    public init(user:User, error:String?) throws {
        try super.init()
        if let passwordHash = user.passwordHash {
            password_hash.addChild(HTMLText(content: passwordHash))
            password_container.globalAttributes[.style] = ""
        }
        if let error = error {
            span_error.addChild(HTMLText(content: error))
            error_container.globalAttributes[.style] = ""
        }
    }
}

extension Request {
    func fetchSession() async throws -> AuthSession? {
        guard let sessionId = session.authenticated(AuthSession.self) else { return nil }
        let connection = try Database.getConnection()
        let session = try await AuthSession.first(connection, uuid:sessionId)
        return session
    }
}

@Sendable func editUser(req: Request) async throws -> Response {
    let connection = try Database.getConnection()
    //let app = req.application
    guard
        let session = try await req.fetchSession(),
        let user = try await connection.read({ db in
            try User.filter(id: session.user).fetchOne(db)
        }) else {
        return try VCWelcomePage(users:[], error:"Session doesn't exist").rootNode.response()
    }
    
    let contents = try req.content.decode(EditUserRequest.self)
    let error = contents.validate()
    if let error = error {
        let response = try VCEditUserPage(user: user, userEditError: error, passwordEditError: nil).rootNode
        return response.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return try VCEditUserPage(user: user, userEditError: nil, passwordEditError: "Password is incorrect.").rootNode.response()
    }
    
    let updatedUser: User = {
        var user = user
        user.email = contents.email
        user.username = contents.username
        user.updatedAt = Date()
        return user
    }()
    let savedUser = try await connection.write { db in
        var user = updatedUser
        try user.update(db)
        return user
    }
    
    let response = try VCEditUserPage(user: savedUser, userEditError: nil, passwordEditError: nil).rootNode
    return response.response()
}
