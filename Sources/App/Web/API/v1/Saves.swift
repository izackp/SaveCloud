//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import Vapor
import SQLite
import Argon2Swift



//GET/DELETE /user/:user_id/profile/:profile_id/games/:game_id/saves?page=0;per_page=10;sort_by=date_desc
//GET/DELETE /user/:user_id/profile/:profile_id/saves?game_hash=xyz;page=0;per_page=10;sort_by=date_desc
@Sendable func apiGETSaves(req: Request) async throws -> [Save] {
    let userId = try req.expectValidUserId()
    let pageInfo = try req.getPageInfo()
    let profileId:UUID? = req.parameters.get("profile_id")
    let gameId:UUID? = req.parameters.get("game_id")
    
    let connection = try Database.getConnection()
    let listSaves = try TblSave.fetchPaged(pageInfo, userId: userId, profileId: profileId, gameId: gameId)
    return listSaves
}

@Sendable func apiDELETESaves(req: Request) async throws {
    let userId = try req.expectValidUserId()
    let pageInfo = try req.getPageInfo()
    let profileId:UUID? = req.parameters.get("profile_id")
    let gameId:UUID? = req.parameters.get("game_id")
    
    let connection = try Database.getConnection()
    try TblSave.deleteAll(userId: userId, profileId: profileId, gameId: gameId, existingCon: connection)
}

//GET/DELETE /save/:save_id
@Sendable func apiGETSave(req: Request) async throws -> Save {
    let (userId, isAdmin) = try req.expectValidAuth()
    guard let saveId:UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    
    let connection = try Database.getConnection()
    guard let result = try connection.first(Save.self, uuid: saveId) else {
        throw Abort(.notFound)
    }
    if (result.userId != userId && !isAdmin) {
        throw Abort(.unauthorized)
    }
    return result
}

@Sendable func apiDELETESave(req: Request) async throws {
    let save = try await apiGETSave(req: req)
    let connection = try Database.getConnection()
    try connection.delete(Save.self, uuid: save.id)
}
