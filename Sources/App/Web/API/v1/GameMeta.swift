//
//  GameMeta.swift
//
//
//  Created by Isaac Paul on 7/10/24.
//
import Vapor
import SQLite

/*
 
 ```
 GET /games/:hash
 GET /games/:id
 GET /games/by_family/:id
 {
     "id": "uuid",
     "hash": "asdadsasd",
     "name": "The Battle for Wesnoth",
     "version": "1.18.0",
     "platform": "windows",
     "family_id": "uuid",
     "created_at": "..",
     "updated_at": "..",
     "patched_game_info": {
         "base_game" : { //For when the game is a mod/patch of an existing game
             "id": "uuid",
             "hash": "asdadsasd",
             "created_at": "..",
             "updated_at": "..",
             etc
         },
         //or
         "base_game_id": "uuid",
         "breaks_save_format": true
     },
     "breaks_save_format": false
 }
 ```
 */

//GET /games?family_id_search=abc&page=0&per_page=10&sort_by=name&asc=1
@Sendable func apiGETGameList(req: Request) async throws -> [GameMeta] {
    //
    let pageInfo:PageInfo<GameMetaSortField> = try req.getPageInfo()
    let searches = GameMetaSearchField.searchFieldsInRequest(req)
    let onlyBaseGames = req.parameters.get("base_games") == "1"
    
    //let connection = try Database.getConnection()
    let listSaves = try TBLGameMeta.fetchPaged(pageInfo, onlyBaseGames: onlyBaseGames, searchList: searches)
    return listSaves
}

//GET /games/:game_id
@Sendable func apiGETGame(req: Request) async throws -> GameMeta {
    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    
    let connection = try Database.getConnection()
    guard let result = try connection.first(GameMeta.self, uuid: gameId) else {
        throw Abort(.notFound)
    }
    return result
}

//We really should allow updating fields that are sent instead of the entire obj
//PUT /games/:game_id
@Sendable func apiPUTGame(req: Request) async throws -> GameMeta {
    let (userId, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    
    let contents = try req.content.decode(GameMetaCreate.self)
    try contents.checkValdiation()
    contents.id = gameId
    
    let connection = try Database.getConnection()
    guard let existing = try connection.first(GameMeta.self, uuid: gameId) else {
        throw Abort(.notFound)
    }
    
    let date = Date()
    let newGameMeta = contents.toGameMeta(date)
    newGameMeta.id = existing.id
    newGameMeta.createdAt = existing.createdAt
    
    try connection.update(GameMeta.self, item: newGameMeta)
    return newGameMeta
}

//POST /games
@Sendable func apiPOSTGame(req: Request) async throws -> GameMeta {
    let (userId, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    let contents = try req.content.decode(GameMetaCreate.self)
    try contents.checkValdiation()
    
    let date = Date()
    let newGameMeta = contents.toGameMeta(date)
    
    let connection = try Database.getConnection()
    try connection.insert(GameMeta.self, item: newGameMeta) //TODO: If UUID not provided by user, and the
    //UUID already exists then we should retry with a new UUID
    //TODO: Check if sqlite does this automatically
    
    return newGameMeta
}

//DELETE /games/:game_id?replace_with_parent=1&allow_break=1
@Sendable func apiDELETEGame(req: Request) async throws {
    let (userId, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    let pageInfo:PageInfo<GameMetaSortField> = try req.getPageInfo()
    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    let replaceWithParent = req.parameters.get("replace_with_parent") == "1"
    let allowRelBreak = req.parameters.get("allow_break") == "1"
    
    let connection = try Database.getConnection()
    try connection.transaction {
        guard let target = try connection.first(GameMeta.self, uuid: gameId) else {
            throw Abort(.notFound)
        }
        let parentId = target.baseGameId
        if let parentId = parentId, replaceWithParent {
            try TBLGameHash.replaceGameMeta(connection, targetUUID: gameId, replaceWith: parentId)
            try TBLGameMeta.replaceBaseGameId(connection, targetUUID: gameId, replaceWith: parentId)
        } else if (allowRelBreak) {
            try TBLGameHash.replaceGameMeta(connection, targetUUID: gameId, replaceWith: nil)
            try TBLGameMeta.replaceBaseGameId(connection, targetUUID: gameId, replaceWith: nil)
        } else {
            let hashCount = try connection.count(GameHash.self, predicate: TBLGameHash.gameMetaId == gameId)
            if (hashCount > 0) {
                throw Abort(.forbidden, reason: "There are game hashes that depend on this game meta.")
            }
            
            let metaCount = try connection.count(GameMeta.self, predicate: TBLGameMeta.baseGameId == gameId)
            if (metaCount > 0) {
                throw Abort(.forbidden, reason: "This game meta has other dependents as children.")
            }
            try connection.delete(GameMeta.self, uuid: gameId)
        }
    }
}
