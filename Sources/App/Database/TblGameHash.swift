//
//  TblGameHash.swift
//
//
//  Created by Isaac Paul on 6/27/24.
//


import Vapor
import SQLite

final class GameHash: Content, SQLItem {
    internal init(id: UUID, gameMetaId: UUID? = nil, hashedFileName: String, xxhash64: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.gameMetaId = gameMetaId
        self.hashedFileName = hashedFileName
        self.xxhash64 = xxhash64
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func getTable() -> SQLite.Table {
        return TBLGameHash.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TBLGameHash.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> GameHash {
        return try TBLGameHash.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> GameHash {
        return try TBLGameHash.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TBLGameHash.toRow(self)
    }
    
    var id: UUID
    var gameMetaId: UUID?
    var hashedFileName: String
    var xxhash64: String
    var createdAt: Date
    var updatedAt: Date
}


class TBLGameHash {
    static let table = Table("game_hash")
    
    static let id = Expression<UUID>("id")
    static let gameMetaId = Expression<UUID?>("game_meta_id")
    static let hashedFileName = Expression<String>("hashed_file_name")
    static let xxhash64 = Expression<String>("xxhash64")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Expression<Date>("updated_at")
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(gameMetaId)
            t.column(hashedFileName)
            t.column(xxhash64)
            t.column(createdAt)
            t.column(updatedAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> GameHash {
        let result = GameHash(
            id: try row.get(id),
            gameMetaId: try row.get(gameMetaId),
            hashedFileName: try row.get(hashedFileName),
            xxhash64: try row.get(xxhash64),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt))
        return result
    }
    
    static func toRow(_ item:GameHash) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.gameMetaId <- item.gameMetaId,
                self.hashedFileName <- item.hashedFileName,
                self.xxhash64 <- item.xxhash64,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt]
    }
    
    static func first(_ con:Connection, uuid:UUID) throws -> GameHash? {
        return try con.first(GameHash.self, uuid: uuid)
    }
    
    static func first(_ con:Connection, hash:String) throws -> GameHash? {
        return try con.first(GameHash.self, predicate: TBLGameHash.xxhash64 == hash)
    }
    
    static func replaceGameMeta(_ con:Connection, targetUUID:UUID, replaceWith:UUID?) throws {
        try con.transaction {
            
            let filtered = table.filter(TBLGameHash.gameMetaId == targetUUID)
            let query = filtered.update(TBLGameHash.gameMetaId <- replaceWith)
            try con.run(query)
            
            let filteredSaveTbl = TblSave.table.filter(TblSave.gameMetaId == targetUUID)
            let query2 = filteredSaveTbl.update(TblSave.gameMetaId <- replaceWith)
            try con.run(query2)
        }
        
    }
    
    static func fetchList(gameMetaId:UUID, existingCon:Connection? = nil) throws -> [GameHash] {
        var filter = table.filter(TBLGameHash.gameMetaId == gameMetaId)
        let con = try Database.getConnection(existingCon)
        let rowIterator = try con.prepareRowIterator(filter)
        
        let list:[GameHash] = try rowIterator.map({ return try toItem($0) })
        return list
    }
}

