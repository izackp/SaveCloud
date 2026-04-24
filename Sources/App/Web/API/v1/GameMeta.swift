//
//  GameMeta.swift
//
//
//  Created by Isaac Paul on 7/10/24.
//
import Vapor
import GRDB

/*
 
 ```
 GET /games?hash=xyz
 GET /games/:id
 GET /games/by_family/:id
 GET /games?family_id_search=abc&page=0&per_page=10&sort_by=name&asc=1
 GET /user/:user_id/profile/:profile_id/games?family_id_search=abc&page=0&per_page=10&sort_by=name&asc=1
 DELETE /games/:game_id?replace_with_parent=1&allow_break=1
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
//GET /user/:user_id/profile/:profile_id/games?family_id_search=abc&page=0&per_page=10&sort_by=name&asc=1
@Sendable func apiGETGameList(req: Request) async throws -> [GameMeta] {
    let userId = try req.validUserIdIfExists()
    let profileId:UUID? = req.parameters.get("profile_id")
    let pageInfo:PageInfo<GameMetaSortField> = try req.getPageInfo()
    var searches = GameMetaSearchField.searchFieldsInRequest(req)
    let onlyBaseGames = (try? req.query.get(String.self, at: "base_games")) == "1"

    if let familyId: UUID = req.parameters.get("family_id") {
        searches.append(SearchQuery(searchBy: .familyId, value: familyId.uuidString))
    }

    let pool = DBShared.pool()
    if let hash = try? req.query.get(String.self, at: "hash") {
        return try await pool.read { db in
            guard let gameHash = try GameHash.first(db, hash: hash), let gameMetaId = gameHash.gameMetaId else {
                return []
            }
            guard let gameMeta = try GameMeta.filter(id: gameMetaId).fetchOne(db) else {
                return []
            }
            return [gameMeta]
        }
    }

    let allowedIds: [UUID]? = if let userId {
        try Save.fetchAllGameIds(userId: userId, profileId: profileId)
    } else {
        nil
    }
    return try GameMeta.fetchPaged(pageInfo, onlyBaseGames: onlyBaseGames, searchList: searches, allowedIds: allowedIds)
}

//GET /games/:game_id
@Sendable func apiGETGame(req: Request) async throws -> GameMeta {
    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    guard let result = try await pool.read({ db in
        try GameMeta.filter(id: gameId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    return result
}

//We really should allow updating fields that are sent instead of the entire obj
//PUT /games/:game_id
@Sendable func apiPUTGame(req: Request) async throws -> GameMeta {
    let (_, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    
    let contents = try req.content.decode(GameMetaCreate.self)
    try contents.checkValdiation()
    contents.id = gameId
    
    let pool = DBShared.pool()
    guard let existing = try await pool.read({ db in
        try GameMeta.filter(id: gameId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    
    let date = Date()
    var newGameMeta = contents.toGameMeta(date)
    newGameMeta.id = existing.id
    newGameMeta.createdAt = existing.createdAt
    let updatedGameMeta = newGameMeta
    
    return try await pool.write { db in
        let gameMeta = updatedGameMeta
        try gameMeta.update(db)
        return gameMeta
    }
}

//POST /games
@Sendable func apiPOSTGame(req: Request) async throws -> GameMeta {
    let (_, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }
    
    let contents = try req.content.decode(GameMetaCreate.self)
    try contents.checkValdiation()
    
    let date = Date()
    let newGameMeta = contents.toGameMeta(date)
    
    let pool = DBShared.pool()
    return try await pool.write { db in
        var gameMeta = newGameMeta
        try gameMeta.insert(db)//TODO: If UUID not provided by user, and the
        //UUID already exists then we should retry with a new UUID
        //TODO: Check if sqlite does this automatically
        return gameMeta
    }
}

//DELETE /games/:game_id?replace_with_parent=1&allow_break=1
@Sendable func apiDELETEGame(req: Request) async throws {
    let (_, isAdmin) = try req.expectValidAuth()
    if (isAdmin == false) {
        throw Abort(.unauthorized)
    }

    guard let gameId:UUID = req.parameters.get("game_id") else {
        throw Abort(.badRequest)
    }
    let replaceWithParent = (try? req.query.get(String.self, at: "replace_with_parent")) == "1"
    let allowRelBreak = (try? req.query.get(String.self, at: "allow_break")) == "1"
    
    let pool = DBShared.pool()
    try await pool.write { db in
        guard let target = try GameMeta.filter(id: gameId).fetchOne(db) else {
            throw Abort(.notFound)
        }
        let parentId = target.baseGameId
        if let parentId = parentId, replaceWithParent {
            try GameHash.replaceGameMeta(db, targetUUID: gameId, replaceWith: parentId)
            try GameMeta.replaceBaseGameId(db, targetUUID: gameId, replaceWith: parentId)
            try GameMeta.filter(id: gameId).deleteAll(db)
        } else if (allowRelBreak) {
            try GameHash.replaceGameMeta(db, targetUUID: gameId, replaceWith: nil)
            try GameMeta.replaceBaseGameId(db, targetUUID: gameId, replaceWith: nil)
            try GameMeta.filter(id: gameId).deleteAll(db)
        } else {
            let hashCount = try GameHash.filter(GameHash.gameMetaId == gameId).fetchCount(db)
            if (hashCount > 0) {
                throw Abort(.forbidden, reason: "There are game hashes that depend on this game meta.")
            }
            
            let metaCount = try GameMeta.filter(GameMeta.baseGameId == gameId).fetchCount(db)
            if (metaCount > 0) {
                throw Abort(.forbidden, reason: "This game meta has other dependents as children.")
            }
            try GameMeta.filter(id: gameId).deleteAll(db)
        }
    }
}
