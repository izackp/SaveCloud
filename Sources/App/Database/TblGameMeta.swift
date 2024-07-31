//
//  GameMeta.swift
//
//
//  Created by Isaac Paul on 5/15/24.
//

import Vapor
import SQLite

final class GameMetaCreate: Content, IValidate {
    internal init(id: UUID?, familyId: UUID? = nil, baseGameId: UUID? = nil, hashedFileName: String? = nil, xxhash64: String? = nil, name: String, version: String? = nil, breaksSaveFormatFromPreviousVersion: Bool, breaksSaveFormatFromBaseGame: Bool) {
        self.id = id
        self.familyId = familyId
        self.baseGameId = baseGameId
        self.hashedFileName = hashedFileName
        self.xxhash64 = xxhash64
        self.name = name
        self.version = version
        self.breaksSaveFormatFromPreviousVersion = breaksSaveFormatFromPreviousVersion
        self.breaksSaveFormatFromBaseGame = breaksSaveFormatFromBaseGame
    }

    var id: UUID?
    var familyId: UUID?
    var baseGameId: UUID?
    var hashedFileName: String?
    var xxhash64: String?
    var name: String
    var version: String?
    var breaksSaveFormatFromPreviousVersion: Bool
    var breaksSaveFormatFromBaseGame: Bool
    
    func toGameMeta(_ date:Date) -> GameMeta {
        return GameMeta(id: id ?? UUID(), name: name, breaksSaveFormatFromPreviousVersion: breaksSaveFormatFromPreviousVersion, breaksSaveFormatFromBaseGame: breaksSaveFormatFromBaseGame, createdAt: date, updatedAt: date)
    }
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if let hashedFileName = hashedFileName, hashedFileName.isEmpty {
                    return "hashedFileName is empty"
                }
                fallthrough
            case 1:
                index += 1
                if let xxhash64 = xxhash64, xxhash64.isEmpty {
                    return "xxhash64 is empty"
                }
                fallthrough
            case 2:
                index += 1
                if name.isEmpty {
                    return "name is empty"
                }
                fallthrough
            case 3:
                index += 1
                if let version = version, version.isEmpty {
                    return "version is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
}

final class GameMeta: Content, SQLItem {
    internal init(id: UUID, familyId: UUID? = nil, baseGameId: UUID? = nil, hashedFileName: String? = nil, xxhash64: String? = nil, name: String, version: String? = nil, breaksSaveFormatFromPreviousVersion: Bool, breaksSaveFormatFromBaseGame: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.familyId = familyId
        self.baseGameId = baseGameId
        self.hashedFileName = hashedFileName
        self.xxhash64 = xxhash64
        self.name = name
        self.version = version
        self.breaksSaveFormatFromPreviousVersion = breaksSaveFormatFromPreviousVersion
        self.breaksSaveFormatFromBaseGame = breaksSaveFormatFromBaseGame
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func getTable() -> SQLite.Table {
        return TBLGameMeta.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TBLGameMeta.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> GameMeta {
        return try TBLGameMeta.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> GameMeta {
        return try TBLGameMeta.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TBLGameMeta.toRow(self)
    }
    

    var id: UUID
    var familyId: UUID?
    var baseGameId: UUID?
    var hashedFileName: String?
    var xxhash64: String?
    var name: String
    var version: String?
    var breaksSaveFormatFromPreviousVersion: Bool
    var breaksSaveFormatFromBaseGame: Bool
    var createdAt: Date
    var updatedAt: Date
}



class TBLGameMeta {
    static let table = Table("game_meta")
    
    static let id = Expression<UUID>("id")
    static let familyId = Expression<UUID?>("family_id")
    static let baseGameId = Expression<UUID?>("base_game_id")
    static let hashedFileName = Expression<String?>("hashed_file_name")
    static let xxhash64 = Expression<String?>("xxhash64")
    static let name = Expression<String>("name")
    static let name_lc = Expression<String>("name_lc") //lower in sqlite lite only works for ascii
    static let version = Expression<String?>("version")
    static let breaksSaveFormatFromPreviousVersion = Expression<Bool>("breaks_save_format_from_previous_version")
    static let breaksSaveFormatFromBaseGame = Expression<Bool>("breaks_save_format_from_base_game")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Expression<Date>("updated_at")
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(familyId)
            t.column(baseGameId)
            t.column(hashedFileName)
            t.column(xxhash64)
            t.column(name)
            t.column(version)
            t.column(breaksSaveFormatFromPreviousVersion)
            t.column(breaksSaveFormatFromBaseGame)
            t.column(createdAt)
            t.column(updatedAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> GameMeta {
        let result = GameMeta(
            id: try row.get(id),
            familyId: try row.get(familyId),
            baseGameId: try row.get(baseGameId),
            hashedFileName: try row.get(hashedFileName),
            xxhash64: try row.get(xxhash64),
            name: try row.get(name),
            version: try row.get(version),
            breaksSaveFormatFromPreviousVersion: try row.get(breaksSaveFormatFromPreviousVersion),
            breaksSaveFormatFromBaseGame: try row.get(breaksSaveFormatFromBaseGame),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt))
        return result
    }
    
    static func toRow(_ item:GameMeta) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.familyId <- item.familyId,
                self.baseGameId <- item.baseGameId,
                self.hashedFileName <- item.hashedFileName,
                self.xxhash64 <- item.xxhash64,
                self.name <- item.name,
                self.version <- item.version,
                self.breaksSaveFormatFromPreviousVersion <- item.breaksSaveFormatFromPreviousVersion,
                self.breaksSaveFormatFromBaseGame <- item.breaksSaveFormatFromBaseGame,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt]
    }
    
    static func first(_ con:Connection, uuid:UUID) throws -> GameMeta? {
        return try con.first(GameMeta.self, uuid: uuid)
    }
    
    static func fetchPaged(_ pageInfo:PageInfo<GameMetaSortField>, onlyBaseGames:Bool, searchList:[SearchQuery<GameMetaSearchField>], existingCon:Connection? = nil) throws -> [GameMeta] {
        var filter:QueryType = table
        for eachSearch in searchList {
            filter = switch (eachSearch.searchBy) {
                case .id:
                    table.filter(TBLGameMeta.id == UUID(eachSearch.value)!)
                case .name:
                    table.filter(TBLGameMeta.name == eachSearch.value)
                case .familyId:
                    table.order(TBLGameMeta.familyId == UUID(eachSearch.value)!)
                case .hashedFileName:
                    table.order(TBLGameMeta.hashedFileName == eachSearch.value)
                case .xxhash64:
                    table.order(TBLGameMeta.xxhash64 == eachSearch.value)
                case .version:
                    table.order(TBLGameMeta.version == eachSearch.value)
            }
        }
        if (onlyBaseGames) {
            filter = filter.filter(TBLGameMeta.baseGameId == nil)
        }
        let asc = pageInfo.sortByAscending
        let sorted = switch (pageInfo.sortBy) {
            case .id:
                filter.order(Connection.id.order(asc: asc))
            case .createdAt:
                filter.order(Connection.createdAt.order(asc: asc))
            case .updatedAt:
                filter.order(Connection.updatedAt.order(asc: asc))
            case .name:
                table.order(TBLGameMeta.name.order(asc: asc))
        }
        let con = try Database.getConnection(existingCon)
        let limited = sorted.limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage*pageInfo.page))
        let rowIterator = try con.prepareRowIterator(limited)
        
        let list:[GameMeta] = try rowIterator.map({ return try toItem($0) })
        return list
    }
    
    static func replaceBaseGameId(_ con:Connection, targetUUID:UUID, replaceWith:UUID?) throws {
        let filtered = table.filter(TBLGameMeta.baseGameId == targetUUID)
        let query = filtered.update(TBLGameMeta.baseGameId <- replaceWith)
        try con.run(query)
    }
}

