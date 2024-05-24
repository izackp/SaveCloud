//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/15/24.
//

import Foundation
import Vapor
import Argon2Swift
import Plot

@Sendable func login(req: Request) async throws -> Response {
    let session = req.session.authenticated(AuthSession.self)
    if (session != nil) {
        return req.redirect(to: "/", redirectType: .normal)
    }
    
    let loginRequest = try req.content.decode(LoginRequest.self)
    if let error = loginRequest.validate() {
        return WelcomePage(error: error).wrapHTML().response()
    }
    
    let connection = try Database.getConnection()
    guard let user = try TblUser.first(connection, emailOrUsername: loginRequest.email_or_username) else {
        return WelcomePage(error: "Username Or Email not found").wrapHTML().response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: loginRequest.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return WelcomePage(error: "Incorrect password").wrapHTML().response()
    }
    let newSession = try createSession(req, user.id, user.isAdmin, connection)
    req.session.authenticate(newSession)
    
    return req.redirect(to: "/", redirectType: .normal)
}

