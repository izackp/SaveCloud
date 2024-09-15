//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import Vapor
import SQLite

/*
 There is a bit of an issue with hashes.
 
 */

//GET /user/:user_id/profile/:profile_id/games/:game_meta_id/saves?page=0&per_page=10&sort_by=date&asc=false
//GET /user/:user_id/profile/:profile_id/saves?game_hash=xyz&page=0&per_page=10&sort_by=date&asc=false
@Sendable func apiGETSaves(req: Request) async throws -> [Save] {
    let userId = try req.expectValidUserId()
    let pageInfo:PageInfo<SaveSortField> = try req.getPageInfo()
    let profileId:UUID? = req.parameters.get("profile_id")
    let gameMetaId:UUID? = req.parameters.get("game_meta_id")
    let gameHash:String? = req.parameters.get("game_hash")
    
    let connection = try Database.getConnection()
    let gameHashId:UUID?
    if let gameHash = gameHash {
        let hashMap = try TBLGameHash.first(connection, hash: gameHash)
        guard let hashMap = hashMap else {
            throw Abort(.notFound, reason: "Can not find a game id that matches hash: \(gameHash)")
        }
        gameHashId = hashMap.id
    } else {
        gameHashId = nil
    }
    
    let hashIdListFromGameMeta:[UUID]
    if let gameMetaId = gameMetaId {
        //if (gameHash != nil) { throw Abort(.badRequest, reason: "Cant look up saves by both game hash and game id.") }
        let matchingHashes = try TBLGameHash.fetchList(gameMetaId: gameMetaId, existingCon: connection)
        if let gameHash = gameHash {
            if (!matchingHashes.contains(where: { $0.xxhash64 == gameHash})) {
                throw Abort(.notFound, reason: "Hash \(gameHash). Not found in game id: \(gameMetaId)")
            }
        }
        hashIdListFromGameMeta = matchingHashes.map({ $0.id })
    } else if let gameHashId = gameHashId {
        hashIdListFromGameMeta = [gameHashId]
    } else {
        hashIdListFromGameMeta = []
    }
    
    let listSaves = try TblSave.fetchPaged(pageInfo, userId: userId, profileId: profileId, gameHashIdList: hashIdListFromGameMeta, existingCon: connection)
    return listSaves
}


//DELETE /user/:user_id/profile/:profile_id/games/:game_meta_id/saves
//DELETE /user/:user_id/profile/:profile_id/saves?game_hash=xyz
@Sendable func apiDELETESaves(req: Request) async throws {
    let userId = try req.expectValidUserId()
    let profileId:UUID? = req.parameters.get("profile_id")
    let gameMetaId:UUID? = req.parameters.get("game_meta_id")
    let gameHash:String? = req.parameters.get("game_hash")
    
    let connection = try Database.getConnection()
    let gameHashId:UUID?
    if let gameHash = gameHash {
        let hashMap = try TBLGameHash.first(connection, hash: gameHash)
        guard let hashMap = hashMap else {
            throw Abort(.notFound, reason: "Can not find a game id that matches hash: \(gameHash)")
        }
        gameHashId = hashMap.id
    } else {
        gameHashId = nil
    }
    
    let hashIdListFromGameMeta:[UUID]
    if let gameMetaId = gameMetaId {
        //if (gameHash != nil) { throw Abort(.badRequest, reason: "Cant look up saves by both game hash and game id.") }
        let matchingHashes = try TBLGameHash.fetchList(gameMetaId: gameMetaId, existingCon: connection)
        if let gameHash = gameHash {
            if (!matchingHashes.contains(where: { $0.xxhash64 == gameHash})) {
                throw Abort(.notFound, reason: "Hash \(gameHash). Not found in game id: \(gameMetaId)")
            }
        }
        hashIdListFromGameMeta = matchingHashes.map({ $0.id })
    } else if let gameHashId = gameHashId {
        hashIdListFromGameMeta = [gameHashId]
    } else {
        //TODO: Scary.. 
        hashIdListFromGameMeta = []
    }
    try TblSave.deleteAll(userId: userId, profileId: profileId, gameHashIdList: hashIdListFromGameMeta, existingCon: connection)
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
/*
@Sendable func upload(req: Request) throws {
        let logger = Logger(label: "StreamController.upload")
        
        // Create a file on disk based on our `Upload` model.
    let fileName = req.headers.first(name: .contentDisposition)
        let upload = StreamModel(fileName: fileName)
        guard FileManager.default.createFile(atPath: upload.filePath(for: req.application),
                                       contents: nil,
                                       attributes: nil) else {
            logger.critical("Could not upload \(upload.fileName)")
            throw Abort(.internalServerError)
        }
        
        // Configure SwiftNIO to create a file stream.
        let nbFileIO = NonBlockingFileIO(threadPool: req.application.threadPool) // Should move out of this func, but left it here for ease of understanding.
        let fileHandle = nbFileIO.openFile(path: upload.filePath(for: req.application),
                                           mode: .write,
                                           eventLoop: req.eventLoop)
        
        // Launch the stream…
        return fileHandle.map { fHand in
            // Vapor request will now feed us bytes
            req.body.drain { someResult -> EventLoopFuture<Void> in
                let drainPromise = req.eventLoop.makePromise(of: Void.self)
                
                switch someResult {
                case .buffer(let buffy):
                    // We have bytes. So, write them to disk, and handle our promise
                    _ = nbFileIO.write(fileHandle: fHand,
                                   buffer: buffy,
                                   eventLoop: req.eventLoop)
                        .always { outcome in
                            switch outcome {
                            case .success(let yep):
                                drainPromise.succeed(yep)
                            case .failure(let err):
                                drainPromise.fail(err)
                            }
                    }
                case .error(let err):
                    do {
                        // Handle errors by closing and removing our file
                        try? fHand.close()
                        try FileManager.default.removeItem(atPath: upload.filePath(for: req.application))
                    } catch {
                        debugPrint("catastrophic failure on \(err)", error)
                    }
                    // Inform the client
                    statusPromise.succeed(.internalServerError)
                    
                case .end:
                    drainPromise.succeed(())
                    _ = upload
                        .save(on: req.db)
                        .map { _ in
                        statusPromise.succeed(.ok)
                    }
                }
                return drainPromise.futureResult
            }
        }.transform(to: statusPromise.futureResult)
    }
*/
