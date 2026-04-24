//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import Vapor
import GRDB
import Argon2Swift

@Sendable func apiGETUserProfiles(req: Request) async throws -> [UserProfile] {
    guard let claims:JWTClaims = req.auth.get() else {
        throw Abort(.internalServerError)
    }
    let userId:UUID = try req.expectValidUserId()
    
    let connection = DBShared.pool()
    guard let user = try await connection.read({ db in
        try User.filter(id: userId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    let profileList = try await connection.read { db in
        try UserProfile.filter(UserProfile.user_id == user.id).fetchAll(db)
    }
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
    
    let userDefinedId = contents.id != nil
    let id = contents.id ?? UUID()
    let date = Date()
    let userProfile = UserProfile(id: id, userId: userId, name: contents.name, createdAt: date, updatedAt: date)
    let connection = DBShared.pool()
    return try await connection.write { db in
        var profile = userProfile
        if userDefinedId {
            try profile.insert(db)
            return profile
        }

        for attempt in 0..<5 {
            do {
                try profile.insert(db)
                return profile
            } catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT && attempt < 4 {
                profile.id = UUID()
            }
        }

        try profile.insert(db)
        return profile
    }
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
    
    let connection = DBShared.pool()
    guard var matchingUserProfile = try await connection.read({ db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (claims.admin || matchingUserProfile.userId == claims.userId)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    matchingUserProfile.updatedAt = Date()
    matchingUserProfile.name = contents.name
    let updatedProfile = matchingUserProfile
    return try await connection.write { db in
        let profile = updatedProfile
        try profile.update(db)
        return profile
    }
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
    
    let connection = DBShared.pool()
    guard let matchingUserProfile = try await connection.read({ db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (claims.admin || claims.userId == matchingUserProfile.userId)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    try await connection.write { db in
        let firstSave = try Save.filter(Save.profileId == profileId).fetchOne(db)
        if (firstSave != nil) {
            throw Abort(.badRequest, reason: "Can not delete profile that contains save data.")
        }
        
        try UserProfile.filter(id: profileId).deleteAll(db)
    }
}
