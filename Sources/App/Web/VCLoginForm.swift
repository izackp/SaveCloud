//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/15/24.
//

import Foundation
import Vapor
import Argon2Swift
import HRW

struct LoginRequest: Content {
    let email_or_username: String
    let password: String
    
    func validate() -> String? {
        if (email_or_username.isEmpty) {
            return "Username/email is empty."
        }
        if (password.isEmpty) {
            return "Password is empty."
        }
        
        return nil
    }
}

struct LoginForm {
    let binding:LoginFormBinding
    let rootNode:Form
    
    public init(_ app:Application) throws {
        let nodes = try app.readHtmlFromFile("LoginForm.html")
        let rootNode = nodes.first as! Form
        binding = try LoginFormBinding(rootNode: rootNode)
        self.rootNode = rootNode
    }
}

@Sendable func login(req: Request) async throws -> Response {
    let app = req.application
    let session = req.session.authenticated(AuthSession.self)
    if (session != nil) {
        return req.redirect(to: "/", redirectType: .normal)
    }
    
    let loginRequest = try req.content.decode(LoginRequest.self)
    if let error = loginRequest.validate() {
        return try WelcomePage(app, users: [], error: error).rootNode.response()
    }
    
    let connection = try Database.getConnection()
    guard let user = try TblUser.first(connection, emailOrUsername: loginRequest.email_or_username) else {
        return try WelcomePage(app, users: [], error: "Username Or Email not found").rootNode.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: loginRequest.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return try WelcomePage(app, users: [], error: "Incorrect password").rootNode.response()
    }
    let newSession = try createSession(req, user.id, user.isAdmin, hours24, UUID.init(), connection)
    req.session.authenticate(newSession)
    //req.auth.login(user)
    
    return req.redirect(to: "/", redirectType: .normal)
}

