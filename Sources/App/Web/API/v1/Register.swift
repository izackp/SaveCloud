//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor
import Argon2Swift
import SQLite

struct ApiRegisterRequest: Content, IValidate {
    let username: String
    let email: String
    let password: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if username.isEmpty {
                    return "Username is empty"
                }
                fallthrough
            case 1:
                index += 1
                if email.isEmpty {
                    return "Email is empty"
                }
                fallthrough
            case 2:
                index += 1
                if password.isEmpty {
                    return "Password is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
    
}

@Sendable func apiRegister(req: Request) async throws -> PublicUser {
    let contents = try req.content.decode(ApiRegisterRequest.self)
    try contents.checkValdiation()
    
    let salt = Salt.newSalt()
    let passwordHash = try Argon2Swift.hashPasswordString(password: contents.password, salt: salt)
    
    let connection = try Database.getConnection()
    let uniqueUsername = try connection.count(User.self, predicate: TblUser.username == contents.username) == 0
    if (!uniqueUsername) {
        throw Abort(.badRequest, reason: "Username \(contents.username) already exists")
    }
    let uniqueEmail = try connection.count(User.self, predicate: TblUser.email == contents.email) == 0
    if (!uniqueEmail) {
        throw Abort(.badRequest, reason: "Email \(contents.username) is already in use")
    }
    let numUsers = try connection.count(User.self)
    let isAdmin = numUsers == 0
    let date = Date()
    let newUser = User(id: UUID.init(), username:contents.username, email: contents.email, passwordHash: passwordHash.encodedString(), isAdmin: isAdmin, createdAt: date, updatedAt: date)
    
    try connection.insert(User.self, item: newUser)
    /*
    //TODO: Build with SEC-CH-UA-PLATFORM etc
    let userAgent = req.headers.first(name: .userAgent)
    //TODO: Add ip address field
    let ipAddress = req.remoteAddress?.ipAddress ?? ""
    //TODO: Odd if empty
    
    let expirationDate = date.advanced(by: 24 * 60 * 60)
    let newSession = AuthSession(id: UUID.init(), user: newUser.id, deviceName: userAgent, location: nil, ipAddress: ipAddress, isAdmin: isAdmin, createdAt: date, updatedAt: date, expiresAt: expirationDate)
    try connection.insert(AuthSession.self, item: newSession)
    */
    //req.session.authenticate(newSession)
    
    return newUser.toPublicUser()
}
