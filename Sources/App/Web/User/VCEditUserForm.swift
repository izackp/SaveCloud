//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/23/24.
//

import Vapor
import Argon2Swift
import HRW
import GRDB

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
        let pool = DBShared.pool()
        return try await pool.read { db in
            try fetchSession(db)
        }
    }
    
    func fetchSession(_ db: GRDB.Database) throws -> AuthSession? {
        guard let sessionId = session.authenticated(AuthSession.self) else { return nil }
        return try AuthSession.filter(id: sessionId).fetchOne(db)
    }
}

@Sendable func editUser(req: Request) async throws -> Response {
    let pool = DBShared.pool()
    //let app = req.application
    let result: (AuthSession?, User?) = try await pool.read { db in
        guard let session = try req.fetchSession(db) else {
            return (nil, nil)
        }
        if let user = try User.filter(id: session.user).fetchOne(db) {
            return (session, user)
        } else {
            return (session, nil)
        }
    }
    let (session, user) = result
    guard session != nil else {
        return try VCWelcomePage(users:[], error:"Session doesn't exist").rootNode.response()
    }
    guard let user = user else {
        return try VCWelcomePage(users:[], error:"User not found").rootNode.response()
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
    let savedUser = try await pool.write { db in
        let user = updatedUser
        try user.update(db)
        return user
    }
    
    let response = try VCEditUserPage(user: savedUser, userEditError: nil, passwordEditError: nil).rootNode
    return response.response()
}
