//
//  TblSession.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import Vapor
import SQLite

final class AuthSession: Content, SQLItem, SessionAuthenticatable {
    public var sessionID: UUID { id }
    
    typealias SessionID = UUID
    
    static func getTable() -> SQLite.Table {
        return TBLSession.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TBLSession.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> AuthSession {
        return try TBLSession.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> AuthSession {
        return try TBLSession.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TBLSession.toRow(self)
    }
    
    internal init(id: UUID, user: UUID, deviceName: String? = nil, location: String? = nil, ipAddress:String, isAdmin: Bool, createdAt: Date, updatedAt: Date, expiresAt: Date) {
        self.id = id
        self.user = user
        self.deviceName = deviceName
        self.location = location
        self.createdAt = createdAt
        self.ipAddress = ipAddress
        self.isAdmin = isAdmin
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
    
    var id: UUID
    var user: UUID
    var deviceName: String?
    var location: String?
    var ipAddress: String
    var isAdmin: Bool
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date

}
 
class TBLSession {
    static let table = Table("session")
    
    static let id = Expression<UUID>("id")
    static let user = Expression<UUID>("user")
    static let deviceName = Expression<String?>("device_name")
    static let location = Expression<String?>("location")
    static let ipAddress = Expression<String>("ipAddress")
    static let isAdmin = Expression<Bool>("is_admin")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Expression<Date>("updated_at")
    static let expiresAt = Expression<Date>("expires_at")
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(user)
            t.column(deviceName)
            t.column(location)
            t.column(ipAddress)
            t.column(isAdmin)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(expiresAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> AuthSession {
        let result = AuthSession(
            id: try row.get(id),
            user: try row.get(user),
            deviceName: try row.get(deviceName),
            location: try row.get(location),
            ipAddress: try row.get(ipAddress),
            isAdmin: try row.get(isAdmin),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt),
            expiresAt: try row.get(expiresAt))
        return result
    }
    
    static func toRow(_ item:AuthSession) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.user <- item.user,
                self.deviceName <- item.deviceName,
                self.location <- item.location,
                self.ipAddress <- item.ipAddress,
                self.isAdmin <- item.isAdmin,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt,
                self.expiresAt <- item.expiresAt]
    }
    
    static func first(_ con:Connection, uuid:UUID) throws -> AuthSession? {
        return try con.first(AuthSession.self, uuid: uuid)
    }
}


