//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import Vapor
import SQLite
import Argon2Swift

@Sendable func apiGETUserProfiles(req: Request) async throws -> [UserProfile] {
    guard let claims:JWTClaims = req.auth.get() else {
        throw Abort(.internalServerError)
    }
    let userId:UUID = try req.expectValidUserId()
    
    let connection = try Database.getConnection()
    guard let user = try connection.first(User.self, uuid: userId) else {
        throw Abort(.notFound)
    }
    let profileList = try connection.fetchAll(UserProfile.self, predicate: TblUserProfile.userId == user.id)
    return profileList
}


final class PlainId: Content {
    
    init(id: UUID) {
        self.id = id
    }
    
    var id: UUID
}

final class PutUserProfile: Content, IValidate {
    
    init(id: UUID?, name:String) {
        self.id = id
        self.name = name
    }
    
    var id: UUID?
    var name: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if name.count > 32 {
                    return "Profile Name is too long"
                }
                fallthrough
            default:
                return nil
        }
    }
}

final class PostUserProfile: Content, IValidate {
    
    init(id: UUID?, name:String) {
        self.id = id
        self.name = name
    }
    
    var id: UUID?
    var userId: UUID?
    var name: String
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if name.count > 32 {
                    return "Profile Name is too long"
                }
                fallthrough
            default:
                return nil
        }
    }
}

//POST /user/:user_id/profile
@Sendable func apiPOSTUserProfile(req: Request) async throws -> UserProfile {
    let (userId, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    let contents = try req.content.decode(PostUserProfile.self)
    try contents.checkValdiation()
    let userIdForProfile = contents.userId ?? userId
    if (!isAdmin && userIdForProfile != userId) {
        throw Abort(.unauthorized, reason: "Cannot create a profile for another user.")
    }
    
    let id:UUID
    let userDefinedId:Bool
    if let profileId = contents.id {
        id = profileId
        userDefinedId = true
    } else {
        id = UUID.init()
        userDefinedId = false
    }
    let date = Date()
    var userProfile = UserProfile(id: id, userId: userId, name: contents.name, createdAt: date, updatedAt: date)
    let connection = try Database.getConnection()
    if (userDefinedId) {
        try connection.insert(UserProfile.self, item: userProfile)
    } else {
        if let newUUID = try connection.insertWithRetry(UserProfile.self, item: userProfile) {
            userProfile.id = newUUID
        }
    }
    
    return userProfile
}

//PUT /user/:user_id/profile/:profile_id
@Sendable func apiPUTUserProfile(req: Request) async throws -> UserProfile {
    guard let claims:JWTClaims = req.auth.get() else {
        throw Abort(.internalServerError)
    }
    let contents = try req.content.decode(PutUserProfile.self)
    try contents.checkValdiation()
    let pathId:UUID? = req.parameters.get("profile_id")
    guard let profileId = pathId ?? contents.id else {
        throw Abort(.badRequest)
    }
    
    let connection = try Database.getConnection()
    guard let matchingUserProfile = try connection.first(UserProfile.self, uuid: profileId) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (claims.admin || matchingUserProfile.userId == claims.userId)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    matchingUserProfile.updatedAt = Date()
    matchingUserProfile.name = contents.name
    try connection.update(UserProfile.self, item: matchingUserProfile)
    
    return matchingUserProfile
}

@Sendable func apiDELETEUserProfile(req: Request) async throws {
    guard let claims:JWTClaims = req.auth.get() else {
        throw Abort(.internalServerError)
    }
    
    let pathId:UUID? = req.parameters.get("profile_id")
    let profileId:UUID
    if let pathId = pathId {
        profileId = pathId
    } else {
        let contents = try req.content.decode(PlainId.self)
        profileId = contents.id
    }
    
    let connection = try Database.getConnection()
    guard let matchingUserProfile = try connection.first(UserProfile.self, uuid: profileId) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (claims.admin || claims.userId == matchingUserProfile.userId)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    try connection.transaction {
        let firstSave = try connection.first(Save.self, predicate: TblSave.profileId == profileId)
        if (firstSave != nil) {
            throw Abort(.badRequest, reason: "Can not delete profile that contains save data.")
        }
        
        try connection.delete(UserProfile.self, uuid: profileId)
    }
}
