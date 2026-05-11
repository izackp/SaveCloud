//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import Vapor
import GRDB

/*
 There is a bit of an issue with hashes.
 
 */

func saveDownloadPath(saveId: UUID) -> String {
    "/saves/\(saveId.uuidString)/download"
}

//GET /user/:user_id/profile/:profile_id/games/:game_meta_id/saves?page=0&per_page=10&sort_by=date&asc=false
//GET /user/:user_id/profile/:profile_id/saves?game_hash=xyz&page=0&per_page=10&sort_by=date&asc=false
@Sendable func apiGETSaves(req: Request) async throws -> [Save] {
    let userId = try req.expectValidUserId()
    let pageInfo:PageInfo<SaveSortField> = try req.getPageInfo()
    let profileId:SmallUid? = req.parameters.get("profile_id")
    let gameMetaId:UUID? = req.parameters.get("game_meta_id")
    let gameHash = try? req.query.get(String.self, at: "game_hash")
    
    let pool = DBShared.pool()
    let (resultHashMap, resultMatchingHashes):(GameHash?, [GameHash]) = try await pool.read { (db:Database) in
        let hashMap:GameHash?
        let matchingHashes:[GameHash]
        if let gameHash = gameHash {
            hashMap = try GameHash.first(db, hash: gameHash)
        } else {
            hashMap = nil
        }
        if let gameMetaId = gameMetaId {
            matchingHashes = try GameHash.fetchList(db, gameMetaId: gameMetaId)
        } else {
            matchingHashes = []
        }
        return (hashMap, matchingHashes)
    }
    
    let gameHashId:UUID?
    if let gameHash = gameHash {
        guard let hashMap = resultHashMap else {
            throw Abort(.notFound, reason: "Can not find a game id that matches hash: \(gameHash)")
        }
        gameHashId = hashMap.id
    } else {
        gameHashId = nil
    }
    
    let hashIdListFromGameMeta:[UUID]
    if let gameMetaId = gameMetaId {
        //if (gameHash != nil) { throw Abort(.badRequest, reason: "Cant look up saves by both game hash and game id.") }
        if let gameHash = gameHash {
            if (!resultMatchingHashes.contains(where: { $0.xxhash64 == gameHash})) {
                throw Abort(.notFound, reason: "Hash \(gameHash). Not found in game id: \(gameMetaId)")
            }
        }
        hashIdListFromGameMeta = resultMatchingHashes.map({ $0.id })
    } else if let gameHashId = gameHashId {
        hashIdListFromGameMeta = [gameHashId]
    } else {
        hashIdListFromGameMeta = []
    }
    
    let listSaves = try Save.fetchPaged(pageInfo, userId: userId, profileId: profileId, gameHashIdList: hashIdListFromGameMeta, existingCon: pool)
    return listSaves
}


//DELETE /user/:user_id/profile/:profile_id/games/:game_meta_id/saves
//DELETE /user/:user_id/profile/:profile_id/saves?game_hash=xyz
@Sendable func apiDELETESaves(req: Request) async throws {
    let userId = try req.expectValidUserId()
    let profileId:SmallUid? = req.parameters.get("profile_id")
    let gameMetaId:UUID? = req.parameters.get("game_meta_id")
    let gameHash = try? req.query.get(String.self, at: "game_hash")
    
    let pool = DBShared.pool()
    let (resultHashMap, resultMatchingHashes):(GameHash?, [GameHash]) = try await pool.read { (db:Database) in
        let hashMap:GameHash?
        let matchingHashes:[GameHash]
        if let gameHash = gameHash {
            hashMap = try GameHash.first(db, hash: gameHash)
        } else {
            hashMap = nil
        }
        if let gameMetaId = gameMetaId {
            matchingHashes = try GameHash.fetchList(db, gameMetaId: gameMetaId)
        } else {
            matchingHashes = []
        }
        return (hashMap, matchingHashes)
    }
    
    let gameHashId:UUID?
    if let gameHash = gameHash {
        guard let hashMap = resultHashMap else {
            throw Abort(.notFound, reason: "Can not find a game id that matches hash: \(gameHash)")
        }
        gameHashId = hashMap.id
    } else {
        gameHashId = nil
    }
    
    let hashIdListFromGameMeta:[UUID]
    if let gameMetaId = gameMetaId {
        //if (gameHash != nil) { throw Abort(.badRequest, reason: "Cant look up saves by both game hash and game id.") }
        if let gameHash = gameHash {
            if (!resultMatchingHashes.contains(where: { $0.xxhash64 == gameHash})) {
                throw Abort(.notFound, reason: "Hash \(gameHash). Not found in game id: \(gameMetaId)")
            }
        }
        hashIdListFromGameMeta = resultMatchingHashes.map({ $0.id })
    } else if let gameHashId = gameHashId {
        hashIdListFromGameMeta = [gameHashId]
    } else {
        //TODO: Scary.. 
        hashIdListFromGameMeta = []
    }
    try Save.deleteAll(userId: userId, profileId: profileId, gameHashIdList: hashIdListFromGameMeta, existingCon: pool)
}

//GET/DELETE /save/:save_id
@Sendable func apiGETSave(req: Request) async throws -> Save {
    let (userId, isAdmin) = try req.expectValidAuth()
    guard let saveId:UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    guard let result = try await pool.read({ db in
        try Save.filter(id: saveId).fetchOne(db)
    }) else {
        throw Abort(.notFound)
    }
    if (result.userId != userId && !isAdmin) {
        throw Abort(.unauthorized)
    }
    return result
}

@Sendable func apiDELETESave(req: Request) async throws {
    let save = try await apiGETSave(req: req)
    let pool = DBShared.pool()
    _ = try await pool.write { db in
        try Save.filter(id: save.id).deleteAll(db)
    }
    if let archivePath = try? SaveArchiveStorage.finalArchivePath(saveId: save.id) {
        try? SaveArchiveStorage.removeIfExists(url: archivePath)
    }
}

final class ApiPostSaveUploadStart: Content, IValidate {
    init(profileId: SmallUid, gameHash: String, fileSize: Int, contentHash: String, sequentialId: UUID? = nil, sourceDevice: String? = nil, name: String? = nil, notes: String? = nil, date: Date? = nil) {
        self.profileId = profileId
        self.gameHash = gameHash
        self.fileSize = fileSize
        self.contentHash = contentHash
        self.sequentialId = sequentialId
        self.sourceDevice = sourceDevice
        self.name = name
        self.notes = notes
        self.date = date
    }
    
    var profileId: SmallUid
    var gameHash: String
    var fileSize: Int
    var contentHash: String
    var sequentialId: UUID?
    var sourceDevice: String?
    var name: String?
    var notes: String?
    var date: Date?
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if gameHash.isEmpty {
                    return "gameHash is empty"
                }
                fallthrough
            case 1:
                index += 1
                if fileSize < 0 {
                    return "fileSize is invalid"
                }
                fallthrough
            case 2:
                index += 1
                if contentHash.isEmpty {
                    return "contentHash is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
}

final class SaveUploadTarget: Content {
    init(method: String, path: String, expiresAt: Date) {
        self.method = method
        self.path = path
        self.expiresAt = expiresAt
    }
    
    var method: String
    var path: String
    var expiresAt: Date
}

final class SaveUploadStartResponse: Content {
    init(uploadId: UUID, target: SaveUploadTarget) {
        self.uploadId = uploadId
        self.target = target
    }
    
    var uploadId: UUID
    var target: SaveUploadTarget
}

final class SaveUploadCompleteResponse: Content {
    init(save: Save) {
        self.save = save
    }
    
    var save: Save
}

final class ApiSaveCompareRequest: Content, IValidate {
    init(profileId: SmallUid, gameHash: String, saveId: UUID? = nil, sequentialId: UUID? = nil, contentHash: String? = nil) {
        self.profileId = profileId
        self.gameHash = gameHash
        self.saveId = saveId
        self.sequentialId = sequentialId
        self.contentHash = contentHash
    }
    
    var profileId: SmallUid
    var gameHash: String
    var saveId: UUID?
    var sequentialId: UUID?
    var contentHash: String?
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if gameHash.isEmpty {
                    return "gameHash is empty"
                }
                fallthrough
            case 1:
                index += 1
                if let contentHash = contentHash, contentHash.isEmpty {
                    return "contentHash is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
}

final class SaveCompareResponse: Content {
    init(status: String, matchingSave: Save?, latestSave: Save?, uploadAllowed: Bool, pullAllowed: Bool, hasDivergence: Bool) {
        self.status = status
        self.matchingSave = matchingSave
        self.latestSave = latestSave
        self.uploadAllowed = uploadAllowed
        self.pullAllowed = pullAllowed
        self.hasDivergence = hasDivergence
    }
    
    var status: String
    var matchingSave: Save?
    var latestSave: Save?
    var uploadAllowed: Bool
    var pullAllowed: Bool
    var hasDivergence: Bool
}

private func saveDateForCompare(_ save: Save) -> Date {
    save.date ?? save.updatedAt
}

private func fetchSaveProfile(_ pool: DatabasePool, profileId: SmallUid) async throws -> UserProfile {
    guard let profile = try await pool.read({ db in
        try UserProfile.filter(id: profileId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Profile not found.")
    }
    return profile
}

private func fetchPendingUpload(_ pool: DatabasePool, uploadId: UUID) async throws -> PendingSaveUpload {
    guard let pendingUpload = try await pool.read({ db in
        try PendingSaveUpload.filter(id: uploadId).fetchOne(db)
    }) else {
        throw Abort(.notFound, reason: "Pending upload not found.")
    }
    return pendingUpload
}

private func resolveGameHash(_ db: Database, hash: String) throws -> GameHash {
    guard let gameHash = try GameHash.first(db, hash: hash) else {
        throw Abort(.notFound, reason: "Can not find a game id that matches hash: \(hash)")
    }
    return gameHash
}

private func fetchAPISessionForDownload(req: Request) async throws -> AuthSession? {
    guard let bearer = req.headers.bearerAuthorization else {
        return nil
    }
    try await APISessionAuthenticator().authenticate(bearer: bearer, for: req)
    return req.auth.get(AuthSession.self)
}

//POST /save/upload/start
@Sendable func apiPOSTSaveUploadStart(req: Request) async throws -> SaveUploadStartResponse {
    let session = try req.authSession()
    let contents = try req.content.decode(ApiPostSaveUploadStart.self)
    try contents.checkValdiation()
    
    let pool = DBShared.pool()
    let profile = try await fetchSaveProfile(pool, profileId: contents.profileId)
    if (profile.userId != session.user && !session.isAdmin) {
        throw Abort(.unauthorized)
    }
    let gameHashValue = contents.gameHash
    
    let gameHash = try await pool.read { db in
        try resolveGameHash(db, hash: gameHashValue)
    }
    
    let now = Date()
    let uploadId = UUID()
    let storageKey = uploadId.uuidString.lowercased()
    let expiresAt = now.advanced(by: 24 * 60 * 60)
    let compatibilityId = UUID()
    let pendingUpload = PendingSaveUpload(
        id: uploadId,
        userId: profile.userId,
        profileId: profile.id,
        gameHashId: gameHash.id,
        gameMetaId: gameHash.gameMetaId,
        compatibilityId: compatibilityId,
        sequentialId: contents.sequentialId ?? UUID(),
        fileSize: contents.fileSize,
        sourceDevice: contents.sourceDevice,
        name: contents.name,
        contentHash: contents.contentHash,
        notes: contents.notes,
        date: contents.date,
        tempStorageKey: storageKey,
        uploadCompletedAt: nil,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now
    )
    
    _ = try await pool.write { db in
        var upload = pendingUpload
        try upload.insert(db)
    }
    
    let target = SaveUploadTarget(
        method: "PUT",
        path: "/api/v1/save/upload/\(uploadId.uuidString)/content",
        expiresAt: expiresAt
    )
    return SaveUploadStartResponse(uploadId: uploadId, target: target)
}

//PUT /save/upload/:upload_id/content
@Sendable func apiPUTSaveUploadContent(req: Request) async throws -> HTTPStatus {
    let session = try req.authSession()
    guard let uploadId: UUID = req.parameters.get("upload_id") else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    let pendingUpload = try await fetchPendingUpload(pool, uploadId: uploadId)
    if (pendingUpload.userId != session.user && !session.isAdmin) {
        throw Abort(.unauthorized)
    }
    if pendingUpload.expiresAt < Date() {
        throw Abort(.gone, reason: "Pending upload expired.")
    }
    
    let buffer = try await req.body.collect(max: nil).get()
    guard var buffer else {
        throw Abort(.badRequest, reason: "No upload body provided.")
    }
    guard let data = buffer.readData(length: buffer.readableBytes) else {
        throw Abort(.badRequest, reason: "Unable to read upload body.")
    }
    if (pendingUpload.fileSize != data.count) {
        throw Abort(.badRequest, reason: "Upload file size does not match declared file size.")
    }
    
    let pendingPath = try SaveArchiveStorage.pendingArchivePath(storageKey: pendingUpload.tempStorageKey)
    try data.write(to: pendingPath, options: .atomic)
    
    try await pool.write { db in
        _ = try PendingSaveUpload
            .filter(id: uploadId)
            .updateAll(
                db,
                PendingSaveUpload.upload_completed_at.set(to: Date()),
                PendingSaveUpload.updated_at.set(to: Date())
            )
    }
    return .ok
}

//POST /save/upload/:upload_id/complete
@Sendable func apiPOSTSaveUploadComplete(req: Request) async throws -> SaveUploadCompleteResponse {
    let session = try req.authSession()
    guard let uploadId: UUID = req.parameters.get("upload_id") else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    let pendingUpload = try await fetchPendingUpload(pool, uploadId: uploadId)
    if (pendingUpload.userId != session.user && !session.isAdmin) {
        throw Abort(.unauthorized)
    }
    if (pendingUpload.uploadCompletedAt == nil) {
        throw Abort(.badRequest, reason: "Upload content not received.")
    }
    
    let pendingArchive = try SaveArchiveStorage.pendingArchivePath(storageKey: pendingUpload.tempStorageKey)
    let fm = FileManager.default
    if (fm.fileExists(atPath: pendingArchive.path()) == false) {
        throw Abort(.badRequest, reason: "Pending upload content is missing.")
    }
    
    let now = Date()
    let save = try await pool.write { db -> Save in
        var compatibility = Compatibility(id: pendingUpload.compatibilityId, updatedAt: now)
        try compatibility.insert(db)
        
        var newSave = Save(
            id: UUID(),
            gameHashId: pendingUpload.gameHashId,
            gameMetaId: pendingUpload.gameMetaId,
            compatibilityId: pendingUpload.compatibilityId,
            sequentialId: pendingUpload.sequentialId,
            profileId: pendingUpload.profileId,
            userId: pendingUpload.userId,
            fileSize: pendingUpload.fileSize,
            sourceDevice: pendingUpload.sourceDevice,
            screenshot: nil,
            name: pendingUpload.name,
            contentHash: pendingUpload.contentHash,
            notes: pendingUpload.notes,
            date: pendingUpload.date,
            createdAt: now,
            updatedAt: now
        )
        try newSave.insert(db)
        try PendingSaveUpload.filter(id: uploadId).deleteAll(db)
        return newSave
    }
    
    do {
        _ = try SaveArchiveStorage.movePendingArchive(storageKey: pendingUpload.tempStorageKey, toSaveId: save.id)
    } catch {
        _ = try await pool.write { db in
            try Save.filter(id: save.id).deleteAll(db)
            try Compatibility.filter(id: pendingUpload.compatibilityId).deleteAll(db)
        }
        throw error
    }
    
    return SaveUploadCompleteResponse(save: save)
}

//POST /save/compare
@Sendable func apiPOSTSaveCompare(req: Request) async throws -> SaveCompareResponse {
    let session = try req.authSession()
    let contents = try req.content.decode(ApiSaveCompareRequest.self)
    try contents.checkValdiation()
    
    let pool = DBShared.pool()
    let profile = try await fetchSaveProfile(pool, profileId: contents.profileId)
    if (profile.userId != session.user && !session.isAdmin) {
        throw Abort(.unauthorized)
    }
    let gameHashValue = contents.gameHash
    let expectedSaveId = contents.saveId
    let expectedSequentialId = contents.sequentialId
    let contentHashValue = contents.contentHash
    
    let (gameHash, saves) = try await pool.read { db -> (GameHash, [Save]) in
        let gameHash = try resolveGameHash(db, hash: gameHashValue)
        let saves = try Save
            .filter(Save.userId == profile.userId && Save.profileId == profile.id && Save.gameHashId == gameHash.id)
            .fetchAll(db)
        return (gameHash, saves)
    }
    _ = gameHash
    
    guard let globalLatestSave = saves.max(by: { saveDateForCompare($0) < saveDateForCompare($1) }) else {
        return SaveCompareResponse(
            status: "upload",
            matchingSave: nil,
            latestSave: nil,
            uploadAllowed: true,
            pullAllowed: false,
            hasDivergence: false
        )
    }
    
    if let expectedSequentialId {
        let sequenceSaves = saves.filter { $0.sequentialId == expectedSequentialId }
        let latestSave = sequenceSaves.max(by: { saveDateForCompare($0) < saveDateForCompare($1) })
        guard let latestSave else {
            return SaveCompareResponse(
                status: "divergence",
                matchingSave: nil,
                latestSave: globalLatestSave,
                uploadAllowed: false,
                pullAllowed: false,
                hasDivergence: true
            )
        }
        let boundSave = expectedSaveId.flatMap { id in sequenceSaves.first(where: { $0.id == id }) }
        if let contentHashValue {
            if latestSave.contentHash == contentHashValue {
                return SaveCompareResponse(
                    status: "exact_match",
                    matchingSave: latestSave,
                    latestSave: latestSave,
                    uploadAllowed: false,
                    pullAllowed: false,
                    hasDivergence: false
                )
            }
            if let boundSave, latestSave.id == boundSave.id {
                return SaveCompareResponse(
                    status: "upload",
                    matchingSave: boundSave,
                    latestSave: latestSave,
                    uploadAllowed: true,
                    pullAllowed: false,
                    hasDivergence: false
                )
            }
            if let boundSave, boundSave.contentHash == contentHashValue {
                return SaveCompareResponse(
                    status: "remote_newer",
                    matchingSave: boundSave,
                    latestSave: latestSave,
                    uploadAllowed: false,
                    pullAllowed: true,
                    hasDivergence: false
                )
            }
            return SaveCompareResponse(
                status: "divergence",
                matchingSave: boundSave,
                latestSave: latestSave,
                uploadAllowed: false,
                pullAllowed: false,
                hasDivergence: true
            )
        }
        if let boundSave, boundSave.id == latestSave.id {
            return SaveCompareResponse(
                status: "exact_match",
                matchingSave: boundSave,
                latestSave: latestSave,
                uploadAllowed: false,
                pullAllowed: false,
                hasDivergence: false
            )
        }
        return SaveCompareResponse(
            status: "remote_newer",
            matchingSave: boundSave,
            latestSave: latestSave,
            uploadAllowed: false,
            pullAllowed: true,
            hasDivergence: false
        )
    }
    
    if let contentHashValue {
        let matchingSave = saves.first(where: { $0.contentHash == contentHashValue })
        if let matchingSave = matchingSave {
            if (matchingSave.id == globalLatestSave.id) {
                return SaveCompareResponse(
                    status: "exact_match",
                    matchingSave: matchingSave,
                    latestSave: globalLatestSave,
                    uploadAllowed: false,
                    pullAllowed: false,
                    hasDivergence: false
                )
            }
            return SaveCompareResponse(
                status: "remote_newer",
                matchingSave: matchingSave,
                latestSave: globalLatestSave,
                uploadAllowed: false,
                pullAllowed: true,
                hasDivergence: false
            )
        }
    }
    
    return SaveCompareResponse(
        status: "divergence",
        matchingSave: nil,
        latestSave: globalLatestSave,
        uploadAllowed: false,
        pullAllowed: false,
        hasDivergence: true
    )
}

//GET /save/:save_id/archive
@Sendable func apiGETSaveArchive(req: Request) async throws -> Response {
    let save = try await apiGETSave(req: req)
    let archivePath = try SaveArchiveStorage.finalArchivePath(saveId: save.id)
    if FileManager.default.fileExists(atPath: archivePath.path()) {
        return req.fileio.streamFile(at: archivePath.path(), mediaType: .zip)
    }
    throw Abort(.notFound, reason: "Archive not found.")
}

@Sendable func saveDownload(req: Request) async throws -> Response {
    guard let saveId: UUID = req.parameters.get("save_id") else {
        throw Abort(.badRequest)
    }
    
    let pool = DBShared.pool()
    let save: Save
    if let apiSession = try await fetchAPISessionForDownload(req: req) {
        guard let result = try await pool.read({ db in
            try Save.filter(id: saveId).fetchOne(db)
        }) else {
            throw Abort(.notFound)
        }
        if (result.userId != apiSession.user && !apiSession.isAdmin) {
            throw Abort(.unauthorized)
        }
        save = result
    } else {
        guard let session = try await req.fetchSession() else {
            return try expiredSessionResponse()
        }
        guard let result = try await pool.read({ db in
            try Save.filter(id: saveId).fetchOne(db)
        }) else {
            throw Abort(.notFound)
        }
        if (result.userId != session.user && !session.isAdmin) {
            throw Abort(.unauthorized)
        }
        save = result
    }
    
    let archivePath = try SaveArchiveStorage.finalArchivePath(saveId: save.id)
    if FileManager.default.fileExists(atPath: archivePath.path()) {
        return req.fileio.streamFile(at: archivePath.path(), mediaType: .zip)
    }
    throw Abort(.notFound, reason: "Archive not found.")
}
