//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor
import Argon2Swift

struct ApiLoginRequest: Content, IValidate {
    let username: String?
    let email: String?
    let password: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if (email == nil && username == nil) {
                    return "No username or email provided"
                }
                if let email = email, email.isEmpty {
                    return "Email is empty"
                } else if let username = username, username.isEmpty {
                    return "Username is empty"
                }
                fallthrough
            case 1:
                index += 1
                if password.isEmpty {
                    return "Password is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
    
    func emailOrUsername() -> String {
        return username ?? email!
    }
}

@Sendable func apiLogin(req: Request) async throws -> PublicUser {
    let contents = try req.content.decode(ApiLoginRequest.self)
    try contents.checkValdiation()
    
    let connection = try Database.getConnection()
    guard let user = try TblUser.first(connection, emailOrUsername: contents.emailOrUsername()) else {
        throw Abort(.notFound, reason: "Username Or Email not found")
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        throw Abort(.unauthorized, reason: "Incorrect password")
    }
    /*
    let newSession = try createSession(req, user.id, user.isAdmin, connection)
    req.session.authenticate(newSession)
    req.auth.login(user)*/
    
    return user.toPublicUser()
}
