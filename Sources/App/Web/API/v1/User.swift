//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor
import GRDB
import Argon2Swift

@Sendable func apiGETUser(req: Request) async throws -> PublicUser {
    let pathId:SmallUid? = req.parameters.get("user_id")
    let userId:SmallUid
    let session = try req.authSession()
    if let pathId = pathId {
        if (pathId != session.user && !session.isAdmin) {
            throw Abort(.unauthorized)
        }
        userId = pathId
    } else {
        userId = session.user
    }
    
    let pool = DBShared.pool()
    guard let user = try await pool.read({ db in
        try User.filter(id: userId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    return user.toPublicUser()
}


final class PutUser: Content, IValidate {
    
    init(id: SmallUid?, username:String?, email: String? = nil, isAdmin:Bool?) {
        self.id = id
        self.username = username
        self.email = email
        self.isAdmin = isAdmin
    }
    
    var id: SmallUid?
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
    let session = try req.authSession()
    let contents = try req.content.decode(PutUser.self)
    try contents.checkValdiation()
    let pathId:SmallUid? = req.parameters.get("user_id")
    guard let id = pathId ?? contents.id else {
        throw Abort(.badRequest, reason: "No user specified.")
    }
    if let pathId = pathId, let contentId = contents.id {
        if (pathId != contentId) {
            throw Abort(.badRequest, reason: "Specified two different users.")
        }
    }
    let allowed = (session.isAdmin || id == session.user)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    
    let pool = DBShared.pool()
    guard var matchingUser = try await pool.read({ db in
        try User.filter(id: id).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "User with id not found: \(id)")
    }
    var isDiff = false
    if let username = contents.username, (matchingUser.username != username) {
        let uniqueUsername = try await pool.read { db in
            try User
                .filter(User.username == username && User.id != id)
                .fetchCount(db) == 0
        }
        if (!uniqueUsername) {
            throw Abort(.badRequest, reason: "Username \(username) already exists")
        }
        matchingUser.username = username
        isDiff = true
    }
    if let email = contents.email, (matchingUser.email != email) {
        let uniqueEmail = try await pool.read { db in
            try User
                .filter(User.email == email && User.id != id)
                .fetchCount(db) == 0
        }
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
    let updatedUser = matchingUser
    let savedUser = try await pool.write { db in
        let user = updatedUser
        try user.update(db)
        return user
    }
    
    return savedUser.toPublicUser()
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
    let session = try req.authSession()
    
    let pathId:SmallUid? = req.parameters.get("user_id")
    let id = pathId ?? session.user
    
    let allowed = (session.isAdmin || session.user == id)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    
    let contents = try req.content.decode(PasswordCheck.self)
    try contents.checkValdiation()
    
    let pool = DBShared.pool()
    guard let matchingUser = try await pool.read({ db in
        try User.filter(id: id).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "User with id not found: \(id)")
    }
    
    let verified = try Argon2Swift.verifyHashString(password: contents.password, hash: matchingUser.passwordHash ?? "")
    if (!verified) {
        throw Abort(.unauthorized, reason: "Incorrect password")
    }
    
    try await pool.write { db in
        try AuthSession.filter(AuthSession.user == id).deleteAll(db)
        try User.filter(id: id).deleteAll(db)
        //TODO: Need to also delete saves, profiles, hashes
    }
    
    return matchingUser.toPublicUser()
}
