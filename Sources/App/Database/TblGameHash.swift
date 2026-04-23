//
//  TblGameHash.swift
//
//
//  Created by Isaac Paul on 6/27/24.
//

import Vapor
import GRDB

final class GameHash: Content, Codable, SQLItem, Identifiable {
    internal init(id: UUID, gameMetaId: UUID? = nil, hashedFileName: String, xxhash64: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.gameMetaId = gameMetaId
        self.hashedFileName = hashedFileName
        self.xxhash64 = xxhash64
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var id: UUID
    var gameMetaId: UUID?
    var hashedFileName: String
    var xxhash64: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case gameMetaId = "game_meta_id"
        case hashedFileName = "hashed_file_name"
        case xxhash64
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static var databaseTableName: String {
        "game_hash"
    }

    static let id = Column(CodingKeys.id)
    static let game_meta_id = Column(CodingKeys.gameMetaId)
    static let hashed_file_name = Column(CodingKeys.hashedFileName)
    static let xxhash64 = Column(CodingKeys.xxhash64)
    static let created_at = Column(CodingKeys.createdAt)
    static let updated_at = Column(CodingKeys.updatedAt)

    static func createTable(db: GRDB.Database) throws {
        if try db.tableExists(databaseTableName) {
            return
        }

        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(game_meta_id, .blob)
            t.column(hashed_file_name, .text).notNull()
            t.column(xxhash64, .text).notNull()
            t.column(created_at, .date).notNull()
            t.column(updated_at, .date).notNull()
        }
    }

}

extension GameHash {
    static let gameMetaId = game_meta_id
    static let hashedFileName = hashed_file_name
    static let createdAt = created_at
    static let updatedAt = updated_at

    static func replaceGameMeta(_ db: GRDB.Database, targetUUID: UUID, replaceWith: UUID?) throws {
        _ = try GameHash
            .filter(GameHash.gameMetaId == targetUUID)
            .updateAll(db, GameHash.gameMetaId.set(to: replaceWith))

        _ = try Save
            .filter(Save.gameMetaId == targetUUID)
            .updateAll(db, Save.gameMetaId.set(to: replaceWith))
    }

    static func first(_ con: DatabasePool, uuid: UUID) throws -> GameHash? {
        try con.read { db in
            try GameHash.filter(id: uuid).fetchOne(db)
        }
    }

    static func first(_ con: DatabasePool, hash: String) throws -> GameHash? {
        try con.read { db in
            try GameHash.filter(xxhash64 == hash).fetchOne(db)
        }
    }

    static func replaceGameMeta(_ con: DatabasePool, targetUUID: UUID, replaceWith: UUID?) throws {
        try con.write { db in
            try replaceGameMeta(db, targetUUID: targetUUID, replaceWith: replaceWith)
        }
    }

    static func fetchList(gameMetaId: UUID, existingCon: DatabasePool? = nil) throws -> [GameHash] {
        let con = try Database.getConnection(existingCon)
        return try con.read { db in
            try GameHash.filter(game_meta_id == gameMetaId).fetchAll(db)
        }
    }
}
