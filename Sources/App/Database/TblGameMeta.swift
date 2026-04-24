//
//  GameMeta.swift
//
//
//  Created by Isaac Paul on 5/15/24.
//

import Vapor
import GRDB

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

    func toGameMeta(_ date: Date) -> GameMeta {
        GameMeta(
            id: id ?? UUID(),
            familyId: familyId,
            baseGameId: baseGameId,
            hashedFileName: hashedFileName,
            xxhash64: xxhash64,
            name: name,
            version: version,
            breaksSaveFormatFromPreviousVersion: breaksSaveFormatFromPreviousVersion,
            breaksSaveFormatFromBaseGame: breaksSaveFormatFromBaseGame,
            createdAt: date,
            updatedAt: date)
    }

    func iterateErrors(_ index: inout Int) -> String? {
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

struct GameMeta: Content, Codable, SQLItem, Identifiable, Sendable {
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

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case baseGameId = "base_game_id"
        case hashedFileName = "hashed_file_name"
        case xxhash64
        case name
        case version
        case breaksSaveFormatFromPreviousVersion = "breaks_save_format_from_previous_version"
        case breaksSaveFormatFromBaseGame = "breaks_save_format_from_base_game"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static var databaseTableName: String {
        "game_meta"
    }

    static let id = Column(CodingKeys.id)
    static let family_id = Column(CodingKeys.familyId)
    static let base_game_id = Column(CodingKeys.baseGameId)
    static let hashed_file_name = Column(CodingKeys.hashedFileName)
    static let xxhash64 = Column(CodingKeys.xxhash64)
    static let name = Column(CodingKeys.name)
    static let name_lc = Column("name_lc") //lower in sqlite lite only works for ascii
    static let version = Column(CodingKeys.version)
    static let breaks_save_format_from_previous_version = Column(CodingKeys.breaksSaveFormatFromPreviousVersion)
    static let breaks_save_format_from_base_game = Column(CodingKeys.breaksSaveFormatFromBaseGame)
    static let created_at = Column(CodingKeys.createdAt)
    static let updated_at = Column(CodingKeys.updatedAt)

    static func createTable(db: GRDB.Database) throws {
        if try db.tableExists(databaseTableName) {
            return
        }

        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(family_id, .blob)
            t.column(base_game_id, .blob)
            t.column(hashed_file_name, .text)
            t.column(xxhash64, .text)
            t.column(name, .text).notNull()
            t.column(name_lc, .text).notNull()
            t.column(version, .text)
            t.column(breaks_save_format_from_previous_version, .boolean).notNull()
            t.column(breaks_save_format_from_base_game, .boolean).notNull()
            t.column(created_at, .date).notNull()
            t.column(updated_at, .date).notNull()
        }
    }

    func encode(to container: inout PersistenceContainer) {
        container[Self.id] = id
        container[Self.family_id] = familyId
        container[Self.base_game_id] = baseGameId
        container[Self.hashed_file_name] = hashedFileName
        container[Self.xxhash64] = xxhash64
        container[Self.name] = name
        container[Self.name_lc] = name.lowercased()
        container[Self.version] = version
        container[Self.breaks_save_format_from_previous_version] = breaksSaveFormatFromPreviousVersion
        container[Self.breaks_save_format_from_base_game] = breaksSaveFormatFromBaseGame
        container[Self.created_at] = createdAt
        container[Self.updated_at] = updatedAt
    }

}

extension GameMeta {
    static func replaceBaseGameId(_ db: GRDB.Database, targetUUID: UUID, replaceWith: UUID?) throws {
        _ = try GameMeta
            .filter(GameMeta.baseGameId == targetUUID)
            .updateAll(db, GameMeta.baseGameId.set(to: replaceWith))
    }

    static let familyId = family_id
    static let baseGameId = base_game_id
    static let hashedFileName = hashed_file_name
    static let breaksSaveFormatFromPreviousVersion = breaks_save_format_from_previous_version
    static let breaksSaveFormatFromBaseGame = breaks_save_format_from_base_game
    static let createdAt = created_at
    static let updatedAt = updated_at

    static func first(_ db: Database, uuid: UUID) throws -> GameMeta? {
        try GameMeta.filter(id: uuid).fetchOne(db)
    }

    static func fetchPaged(_ pageInfo: PageInfo<GameMetaSortField>, onlyBaseGames: Bool, searchList: [SearchQuery<GameMetaSearchField>], existingCon: DatabasePool? = nil) throws -> [GameMeta] {
        var filter: QueryInterfaceRequest<GameMeta> = all()
        for eachSearch in searchList {
            switch eachSearch.searchBy {
            case .id:
                if let value = UUID(eachSearch.value) {
                    filter = filter.filter(id == value)
                }
            case .name:
                filter = filter.filter(name == eachSearch.value)
            case .familyId:
                if let value = UUID(eachSearch.value) {
                    filter = filter.filter(family_id == value)
                }
            case .hashedFileName:
                filter = filter.filter(hashed_file_name == eachSearch.value)
            case .xxhash64:
                filter = filter.filter(xxhash64 == eachSearch.value)
            case .version:
                filter = filter.filter(version == eachSearch.value)
            }
        }
        if onlyBaseGames {
            filter = filter.filter(base_game_id == nil)
        }

        let sorted: QueryInterfaceRequest<GameMeta>
        if pageInfo.sortByAscending {
            sorted = switch pageInfo.sortBy {
            case .id:
                filter.order(id.asc)
            case .createdAt:
                filter.order(created_at.asc)
            case .updatedAt:
                filter.order(updated_at.asc)
            case .name:
                filter.order(name.asc)
            }
        } else {
            sorted = switch pageInfo.sortBy {
            case .id:
                filter.order(id.desc)
            case .createdAt:
                filter.order(created_at.desc)
            case .updatedAt:
                filter.order(updated_at.desc)
            case .name:
                filter.order(name.desc)
            }
        }

        let con = existingCon ?? DBShared.pool()
        return try con.read { db in
            try sorted
                .limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage * pageInfo.page))
                .fetchAll(db)
        }
    }
}
