//
//  TblSaves.swift
//
//
//  Created by Isaac Paul on 6/28/24.
//

/*
 [{
     "id":"uuid",
     "game_id":"uuid",
     "sequntial_id":"uuid",
     "sequence":"2",
     "screenshot":"Base64;asdadsasd", //Maybe a url? it would need to be less than 100kb for embedded to be viable
     "created_at":"..",
     "updated_at":"..",
     //Maybe include patch support? not necessisary for v1
     "patch_from_last_save":"http://path.to/patch.zip",
     "hash":"abc", //To verify the patch applies to your save
 }]
 */

import GRDB
import Vapor

struct Save: Content, Codable, SQLItem, Identifiable, Sendable {
    internal init(id: UUID, gameHashId: UUID, gameMetaId: UUID?, compatibilityId: UUID, sequentialId: UUID, profileId: SmallUid, userId: SmallUid, fileSize: Int, sourceDevice: String? = nil, screenshot: Data? = nil, name: String? = nil, contentHash: String? = nil, notes: String? = nil, date: Date? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.gameHashId = gameHashId
        self.gameMetaId = gameMetaId
        self.compatibilityId = compatibilityId
        self.sequentialId = sequentialId
        self.profileId = profileId
        self.userId = userId
        self.fileSize = fileSize
        self.sourceDevice = sourceDevice
        self.screenshot = screenshot
        self.name = name
        self.contentHash = contentHash
        self.notes = notes
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var id: UUID
    var gameHashId: UUID
    var gameMetaId: UUID?
    var compatibilityId: UUID
    var sequentialId: UUID
    var profileId: SmallUid
    var userId: SmallUid
    var fileSize: Int
    var sourceDevice: String?
    var screenshot: Data?
    var name: String?
    var contentHash: String?
    var notes: String?
    var date: Date?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gameHashId = "game_hash_id"
        case gameMetaId = "game_meta_id"
        case compatibilityId = "compatibility_id"
        case sequentialId = "sequential_id"
        case profileId = "profile_id"
        case userId = "user_id"
        case fileSize = "file_size"
        case sourceDevice = "source_device"
        case screenshot
        case name
        case contentHash = "content_hash"
        case notes
        case date
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static var databaseTableName: String {
        "save"
    }

    static let id = Column(CodingKeys.id)
    static let game_hash_id = Column(CodingKeys.gameHashId)
    static let game_meta_id = Column(CodingKeys.gameMetaId)
    static let compatibility_id = Column(CodingKeys.compatibilityId)
    static let sequential_id = Column(CodingKeys.sequentialId)
    static let profile_id = Column(CodingKeys.profileId)
    static let user_id = Column(CodingKeys.userId)
    static let file_size = Column(CodingKeys.fileSize)
    static let source_device = Column(CodingKeys.sourceDevice)
    static let screenshot = Column(CodingKeys.screenshot)
    static let name = Column(CodingKeys.name)
    static let content_hash = Column(CodingKeys.contentHash)
    static let notes = Column(CodingKeys.notes)
    static let date = Column(CodingKeys.date)
    static let created_at = Column(CodingKeys.createdAt)
    static let updated_at = Column(CodingKeys.updatedAt)

    static func createTable(db: GRDB.Database) throws {
        if try db.tableExists(databaseTableName) {
            return
        }

        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(game_hash_id, .blob).notNull()
            t.column(game_meta_id, .blob)
            t.column(compatibility_id, .blob).notNull()
            t.column(sequential_id, .blob).notNull()
            t.column(profile_id, .blob).notNull()
            t.column(user_id, .blob).notNull()
            t.column(file_size, .integer).notNull()
            t.column(source_device, .text)
            t.column(screenshot, .blob)
            t.column(name, .text)
            t.column(content_hash, .text)
            t.column(notes, .text)
            t.column(date, .date)
            t.column(created_at, .date).notNull()
            t.column(updated_at, .date).notNull()
        }
    }

}

extension Save {
    static let gameHashId = game_hash_id
    static let gameMetaId = game_meta_id
    static let compatibilityId = compatibility_id
    static let sequentialId = sequential_id
    static let profileId = profile_id
    static let userId = user_id
    static let fileSize = file_size
    static let sourceDevice = source_device
    static let contentHash = content_hash
    static let createdAt = created_at
    static let updatedAt = updated_at

    private static func baseRequest(userId: SmallUid, profileId: SmallUid?, gameHashId: UUID?) -> QueryInterfaceRequest<Save> {
        var filter = all().filter(self.user_id == userId)
        if let profileId {
            filter = filter.filter(self.profile_id == profileId)
        }
        if let gameHashId {
            filter = filter.filter(self.game_hash_id == gameHashId)
        }
        return filter
    }

    private static func baseRequest(userId: SmallUid, profileId: SmallUid?, gameHashIdList: [UUID]) -> QueryInterfaceRequest<Save> {
        var filter = all().filter(self.user_id == userId)
        if let profileId {
            filter = filter.filter(self.profile_id == profileId)
        }
        if gameHashIdList.count > 1 {
            filter = filter.filter(gameHashIdList.contains(self.game_hash_id))
        } else if let first = gameHashIdList.first {
            filter = filter.filter(self.game_hash_id == first)
        }
        return filter
    }

    private static func applySort(_ filter: QueryInterfaceRequest<Save>, pageInfo: PageInfo<SaveSortField>) -> QueryInterfaceRequest<Save> {
        if pageInfo.sortByAscending {
            return switch pageInfo.sortBy {
            case .id:
                filter.order(id.asc)
            case .createdAt:
                filter.order(created_at.asc)
            case .updatedAt:
                filter.order(updated_at.asc)
            case .date:
                filter.order(date.asc)
            }
        } else {
            return switch pageInfo.sortBy {
            case .id:
                filter.order(id.desc)
            case .createdAt:
                filter.order(created_at.desc)
            case .updatedAt:
                filter.order(updated_at.desc)
            case .date:
                filter.order(date.desc)
            }
        }
    }

    private static func baseRequest() -> QueryInterfaceRequest<Save> {
        all()
    }

    static func fetchPaged(_ pageInfo: PageInfo<SaveSortField>, existingCon: DatabasePool? = nil) throws -> [Save] {
        let pool = existingCon ?? DBShared.pool()
        let request = applySort(baseRequest(), pageInfo: pageInfo)
        return try pool.read { db in
            try request
                .limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage * pageInfo.page))
                .fetchAll(db)
        }
    }

    static func fetchPaged(_ pageInfo: PageInfo<SaveSortField>, userId: SmallUid, profileId: SmallUid?, gameHashId: UUID?, existingCon: DatabasePool? = nil) throws -> [Save] {
        let pool = existingCon ?? DBShared.pool()
        let request = applySort(baseRequest(userId: userId, profileId: profileId, gameHashId: gameHashId), pageInfo: pageInfo)
        return try pool.read { db in
            try request
                .limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage * pageInfo.page))
                .fetchAll(db)
        }
    }

    static func fetchPaged(_ pageInfo: PageInfo<SaveSortField>, userId: SmallUid, profileId: SmallUid?, gameHashIdList: [UUID], existingCon: DatabasePool? = nil) throws -> [Save] {
        let pool = existingCon ?? DBShared.pool()
        let request = applySort(baseRequest(userId: userId, profileId: profileId, gameHashIdList: gameHashIdList), pageInfo: pageInfo)
        return try pool.read { db in
            try request
                .limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage * pageInfo.page))
                .fetchAll(db)
        }
    }

    static func deleteAll(userId: SmallUid, profileId: SmallUid?, gameHashIdList: [UUID], existingCon: DatabasePool? = nil) throws {
        let pool = existingCon ?? DBShared.pool()
        try pool.write { db in
            _ = try baseRequest(userId: userId, profileId: profileId, gameHashIdList: gameHashIdList).deleteAll(db)
        }
    }

    static func fetchAllGameIds(userId: SmallUid, profileId: SmallUid?, existingCon: DatabasePool? = nil) throws -> [UUID] {
        let pool = existingCon ?? DBShared.pool()
        return try pool.read { db in
            try baseRequest(userId: userId, profileId: profileId, gameHashIdList: [])
                .select(game_meta_id)
                .fetchAll(db)
                .compactMap { row in row[game_meta_id] as UUID? }
        }
    }
}
