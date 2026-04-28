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

struct RegisterRequest: Content {
    let username: String
    let email: String
    let password: String
    let password_confirmation: String
}

class VCRegistrationForm : RegistrationForm {
    let error:String?
    
    public init(error: String? = nil) throws {
        self.error = error
        try super.init()
        if let error = error {
            error_text.addChild(HTMLText(content: error))
        }
    }
}


@Sendable func register(req: Request) async throws -> Response {//EventLoopFuture<AuthSession> {
    let app = req.application
    let contents = try req.content.decode(RegisterRequest.self)
    var errors = [String]()
    //var usernameError = false
    //var passwordError = false
    if contents.email.count == 0  {
        errors.append("You must supply your username")
        //usernameError = true
    }
    if contents.password.count == 0 {
        errors.append("You must supply your password")
        //passwordError = true
    }
    if contents.password != contents.password_confirmation {
        errors.append("Passwords do not match")
        //passwordError = true
    }
    if !errors.isEmpty {
        let response = try VCRegistrationForm(error: errors.joined(separator: "\n")).rootNode
        return response.response()
        //throw Abort(.unauthorized)
        //return some view
    }
    
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: contents.password, salt: salt)
    let encodedPassword = passwordHash.encodedString()
    
    let pool = DBShared.pool()
    let numUsers = try await pool.read { db in
        try User.fetchCount(db)
    }
    let isAdmin = numUsers == 0
    let date = Date()
    let newUser = try await pool.write { db in
        var user = User(id: SmallUid(), username:contents.username, email: contents.email, passwordHash: encodedPassword, isAdmin: isAdmin, createdAt: date, updatedAt: date)
        try user.insert(db)
        return user
    }
    
    //TODO: Build with SEC-CH-UA-PLATFORM etc
    let userAgent = req.headers.first(name: .userAgent)
    //TODO: Add ip address field
    let ipAddress = req.remoteAddress?.ipAddress ?? ""
    //TODO: Odd if empty
    
    let expirationDate = date.advanced(by: 24 * 60 * 60)
    let newSession = try await pool.write { db in
        var session = AuthSession(id: UUID(), refreshToken: UUID(), user: newUser.id, deviceName: userAgent, location: nil, ipAddress: ipAddress, isAdmin: isAdmin, createdAt: date, updatedAt: date, expiresAt: expirationDate)
        try session.insert(db)
        return session
    }
    
    let response = req.redirect(to: "/", redirectType: .normal)
    setBrowserSessionCookie(on: response, session: newSession)
    return response
}
