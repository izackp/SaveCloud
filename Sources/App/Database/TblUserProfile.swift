//
//  File.swift
//  
//
//  Created by Isaac Paul on 6/28/24.
//

import SQLite
import Vapor

final class UserProfile: Content, SQLItem {
    internal init(id: UUID, userId: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    static func getTable() -> SQLite.Table {
        return TblUserProfile.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TblUserProfile.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> UserProfile {
        return try TblUserProfile.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> UserProfile {
        return try TblUserProfile.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TblUserProfile.toRow(self)
    }
    
    var id: UUID
    var userId: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
}

class TblUserProfile {
    static let table = Table("user_profile")
    
    static let id = Connection.id
    static let userId = Expression<UUID>("user_id")
    static let name = Expression<String>("name")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Connection.updatedAt
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(userId)
            t.column(name)
            t.column(createdAt)
            t.column(updatedAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> UserProfile {
        let result = UserProfile(
            id: try row.get(id),
            userId: try row.get(userId),
            name: try row.get(name),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt))
        return result
    }
    
    static func toRow(_ item:UserProfile) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.userId <- item.userId,
                self.name <- item.name,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt]
    }
}


