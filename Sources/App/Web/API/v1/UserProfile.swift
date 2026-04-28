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
    let userId:UUID = try req.expectValidUserId()
    
    let pool = DBShared.pool()
    guard let user = try await pool.read({ db in
        try User.filter(id: userId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    let profileList = try await pool.read { db in
        try UserProfile.filter(UserProfile.user_id == user.id).fetchAll(db)
    }
    return profileList
}


final class PlainId: Content {
    
    init(id: SmallUid) {
        self.id = id
    }
    
    var id: SmallUid
}

final class PutUserProfile: Content, IValidate {
    
    init(id: SmallUid?, name:String) {
        self.id = id
        self.name = name
    }
    
    var id: SmallUid?
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
    
    init(id: SmallUid?, name:String) {
        self.id = id
        self.name = name
    }
    
    var id: SmallUid?
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
    let pathUserId: UUID? = req.parameters.get("user_id")
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    let contents = try req.content.decode(PostUserProfile.self)
    try contents.checkValdiation()
    let userIdForProfile = contents.userId ?? pathUserId ?? userId
    if (!isAdmin && userIdForProfile != userId) {
        throw Abort(.unauthorized, reason: "Cannot create a profile for another user.")
    }
    
    let userDefinedId = contents.id != nil
    let id = contents.id ?? SmallUid.generate()
    let date = Date()
    let userProfile = UserProfile(id: id, userId: userIdForProfile, name: contents.name, createdAt: date, updatedAt: date)
    let pool = DBShared.pool()
    return try await pool.write { db in
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
                profile.id = SmallUid.generate()
            }
        }

        try profile.insert(db)
        return profile
    }
}

//PUT /user/:user_id/profile/:profile_id
@Sendable func apiPUTUserProfile(req: Request) async throws -> UserProfile {
    let session = try req.authSession()
    let contents = try req.content.decode(PutUserProfile.self)
    try contents.checkValdiation()
    let pathId:SmallUid? = req.parameters.get("profile_id")
    guard let profileId = pathId ?? contents.id else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    guard var matchingUserProfile = try await pool.read({ db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (session.isAdmin || matchingUserProfile.userId == session.user)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    matchingUserProfile.updatedAt = Date()
    matchingUserProfile.name = contents.name
    let updatedProfile = matchingUserProfile
    return try await pool.write { db in
        let profile = updatedProfile
        try profile.update(db)
        return profile
    }
}

@Sendable func apiDELETEUserProfile(req: Request) async throws {
    let session = try req.authSession()
    
    let pathId:SmallUid? = req.parameters.get("profile_id")
    let profileId:SmallUid
    if let pathId = pathId {
        profileId = pathId
    } else {
        let contents = try req.content.decode(PlainId.self)
        profileId = contents.id
    }
    
    let pool = DBShared.pool()
    guard let matchingUserProfile = try await pool.read({ db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Profile with id not found: \(profileId)")
    }
    
    let allowed = (session.isAdmin || session.user == matchingUserProfile.userId)
    if (!allowed) {
        throw Abort(.unauthorized, reason: "You don't have permission to edit this user.")
    }
    try await pool.write { db in
        let firstSave = try Save.filter(Save.profileId == profileId).fetchOne(db)
        if (firstSave != nil) {
            throw Abort(.badRequest, reason: "Can not delete profile that contains save data.")
        }
        
        try UserProfile.filter(id: profileId).deleteAll(db)
    }
}
