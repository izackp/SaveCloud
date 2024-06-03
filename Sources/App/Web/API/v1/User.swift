//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor
import SQLite
import Argon2Swift

@Sendable func apiGETUser(req: Request) async throws -> PublicUser {
    guard let user:User = req.auth.get() else {
        throw Abort(.internalServerError, reason: "No session found")
    }
    
    return user.toPublicUser()
}


final class PutUser: Content, IValidate {
    
    init(id: UUID?, username:String?, email: String? = nil, isAdmin:Bool?) {
        self.id = id
        self.username = username
        self.email = email
        self.isAdmin = isAdmin
    }
    
    var id: UUID? //TODO: Test invalid UUID
    var username: String?
    var email: String?
    var isAdmin: Bool?
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if let username = username, username.isEmpty {
                    return "Username is empty"
                }
                fallthrough
            case 1:
                index += 1
                if let email = email, email.isEmpty {
                    return "Email is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
}

@Sendable func apiPUTUser(req: Request) async throws -> PublicUser {
    guard let user:User = req.auth.get() else {
        throw Abort(.internalServerError, reason: "No session found")
    }
    let contents = try req.content.decode(PutUser.self)
    try contents.checkValdiation()
    let pathId:UUID? = req.parameters.get("id")
    guard let id = pathId ?? contents.id else {
        throw Abort(.badRequest, reason: "No user specified.")
    }
    if let pathId = pathId, let contentId = contents.id {
        throw Abort(.badRequest, reason: "Specified two different users.")
    }
    let allowed = (user.isAdmin || contents.id == user.id)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    
    let connection = try Database.getConnection()
    guard let matchingUser = try connection.first(User.self, uuid: id) else {
        throw Abort(.notFound, reason: "User with id not found: \(id)")
    }
    var isDiff = false
    if let username = contents.username, (matchingUser.username != username) {
        let uniqueUsername = try connection.count(User.self, predicate: TblUser.username == username) == 0
        if (!uniqueUsername) {
            throw Abort(.badRequest, reason: "Username \(username) already exists")
        }
        matchingUser.username = username
        isDiff = true
    }
    if let email = contents.email, (matchingUser.email != email) {
        let uniqueEmail = try connection.count(User.self, predicate: TblUser.email == email) == 0
        if (!uniqueEmail) {
            throw Abort(.badRequest, reason: "Email \(email) is already in use")
        }
        matchingUser.email = email
        isDiff = true
    }
    if let isAdmin = contents.isAdmin, (matchingUser.isAdmin != isAdmin) {
        matchingUser.isAdmin = isAdmin
        isDiff = true
    }
    if (isDiff == false) {
        return matchingUser.toPublicUser()
    }
    matchingUser.updatedAt = Date()
    try connection.update(User.self, item: matchingUser)
    
    return user.toPublicUser()
}

final class PasswordCheck: Content, IValidate {
    
    init(password:String) {
        self.password = password
    }
    
    var password: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
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

@Sendable func apiDELETEUser(req: Request) async throws -> PublicUser {
    guard let user:User = req.auth.get() else {
        throw Abort(.internalServerError, reason: "No session found")
    }
    
    let pathId:UUID? = req.parameters.get("id")
    let id = pathId ?? user.id
    
    let allowed = (user.isAdmin || user.id == id)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    
    let contents = try req.content.decode(PasswordCheck.self)
    try contents.checkValdiation()
    
    let connection = try Database.getConnection()
    guard let matchingUser = try connection.first(User.self, uuid: id) else {
        throw Abort(.notFound, reason: "User with id not found: \(id)")
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: user.passwordHash ?? "")
    if (!verified) {
        throw Abort(.unauthorized, reason: "Incorrect password")
    }
    
    try connection.transaction {
        try connection.deleteAll(AuthSession.self, predicate: TBLSession.user == id)
        try connection.delete(User.self, uuid: id)
    }
    
    return user.toPublicUser()
}
