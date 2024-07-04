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
     "url":"http://path.to/save.zip",
     "screenshot":"Base64;asdadsasd", //Maybe a url? it would need to be less than 100kb for embedded to be viable
     "created_at":"..",
     "updated_at":"..",
     //Maybe include patch support? not necessisary for v1
     "patch_from_last_save":"http://path.to/patch.zip",
     "hash":"abc", //To verify the patch applies to your save
 }]
 */

import SQLite
import Vapor

final class Save: Content, SQLItem {
    internal init(id: UUID, gameId: UUID, sequentialId: UUID, profileId: UUID, userId: UUID, url: String, fileSize: Int, sourceDevice: String? = nil, screenshot: Data? = nil, name: String? = nil, date: Date? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.gameId = gameId
        self.sequentialId = sequentialId
        self.profileId = profileId
        self.userId = userId
        self.url = url
        self.fileSize = fileSize
        self.sourceDevice = sourceDevice
        self.screenshot = screenshot
        self.name = name
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func getTable() -> SQLite.Table {
        return TblSave.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TblSave.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> Save {
        return try TblSave.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> Save {
        return try TblSave.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TblSave.toRow(self)
    }
    
    var id: UUID
    var gameId: UUID
    var sequentialId: UUID
    var profileId: UUID
    var userId: UUID
    var url: String
    var fileSize: Int
    var sourceDevice: String?
    var screenshot: Data?
    var name: String?
    var date: Date?
    var createdAt: Date
    var updatedAt: Date
}

class TblSave {
    static let table = Table("save")
    
    static let id = Connection.id
    static let gameId = Expression<UUID>("game_id")
    static let sequentialId = Expression<UUID>("sequential_id")
    static let profileId = Expression<UUID>("profile_id")
    static let userId = Expression<UUID>("user_id")
    static let url = Expression<String>("url")
    static let fileSize = Expression<Int>("file_size")
    static let sourceDevice = Expression<String?>("source_device")
    static let screenshot = Expression<Data?>("screenshot")
    static let name = Expression<String?>("name")
    static let date = Expression<Date?>("date")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Connection.updatedAt
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(gameId)
            t.column(sequentialId)
            t.column(profileId)
            t.column(userId)
            t.column(url)
            t.column(fileSize)
            t.column(sourceDevice)
            t.column(screenshot)
            t.column(name)
            t.column(date)
            t.column(createdAt)
            t.column(updatedAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> Save {
        let result = Save(
            id: try row.get(id),
            gameId: try row.get(gameId),
            sequentialId: try row.get(sequentialId),
            profileId: try row.get(profileId),
            userId: try row.get(userId),
            url: try row.get(url),
            fileSize: try row.get(fileSize),
            sourceDevice: try row.get(sourceDevice),
            screenshot: try row.get(screenshot),
            name: try row.get(name),
            date: try row.get(date),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt))
        return result
    }
    
    static func toRow(_ item:Save) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.gameId <- item.gameId,
                self.sequentialId <- item.sequentialId,
                self.profileId <- item.profileId,
                self.url <- item.url,
                self.fileSize <- item.fileSize,
                self.screenshot <- item.screenshot,
                self.name <- item.name,
                self.date <- item.date,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt]
    }
    
    static func fetchPaged(_ pageInfo:PageInfo, userId:UUID, profileId:UUID?, gameId:UUID?, existingCon:Connection? = nil) throws -> [Save] {
        var filter = table.filter(TblSave.userId == userId)
        if let profileId = profileId {
            filter = table.filter(TblSave.profileId == profileId)
        }
        if let gameId = gameId {
            filter = table.filter(TblSave.gameId == gameId)
        }
        let asc = pageInfo.sortByAscending
        let sorted = switch (pageInfo.sortBy) {
            case .id:
                filter.order(Connection.id.order(asc: asc))
            case .createdAt:
                filter.order(Connection.createdAt.order(asc: asc))
            case .updatedAt:
                filter.order(Connection.updatedAt.order(asc: asc))
            case .date:
                filter.order(TblSave.date.order(asc: asc))
        }
        let con = try Database.getConnection(existingCon)
        let limited = sorted.limit(Int(pageInfo.perPage), offset: Int(pageInfo.perPage*pageInfo.page))
        let rowIterator = try con.prepareRowIterator(limited)
        
        let list:[Save] = try rowIterator.map({ return try toItem($0) })
        return list
    }
    
    static func deleteAll(userId:UUID, profileId:UUID?, gameId:UUID?, existingCon:Connection? = nil) throws {
        var filter = table.filter(TblSave.userId == userId)
        if let profileId = profileId {
            filter = table.filter(TblSave.profileId == profileId)
        }
        if let gameId = gameId {
            filter = table.filter(TblSave.gameId == gameId)
        }
        let con = try Database.getConnection(existingCon)
        let query = filter.delete()
        try con.run(query)
    }
}

