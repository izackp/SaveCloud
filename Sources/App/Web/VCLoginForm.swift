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

@Sendable func login(req: Request) async throws -> Response {
    //let app = req.application
    //TODO: The user might login with different credentials. We shouldn't redirect
    let session = try await req.fetchSession()
    if (session != nil) {
        return req.redirect(to: "/", redirectType: .normal)
    }
    
    let loginRequest = try req.content.decode(LoginRequest.self)
    if let error = loginRequest.validate() {
        return try VCWelcomePage(users: [], error: error).rootNode.response()
    }
    
    let pool = DBShared.pool()
    guard let user = try await User.first(emailOrUsername: loginRequest.email_or_username, pool) else {
        return try VCWelcomePage(users: [], error: "Username Or Email not found").rootNode.response()
    }
    
    let verified = try Argon2Swift.verifyHashString(password: loginRequest.password, hash: user.passwordHash ?? "")
    if (!verified) {
        return try VCWelcomePage(users: [], error: "Incorrect password").rootNode.response()
    }
    let newSession = try await createSession(req, user.id, user.isAdmin, hours24, UUID(), pool)
    let response = req.redirect(to: "/", redirectType: .normal)
    setBrowserSessionCookie(on: response, session: newSession)
    return response
}
