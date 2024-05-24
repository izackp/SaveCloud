//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/15/24.
//

import Foundation

import Foundation
import Vapor
import SQLite

final class AuthToken: Content, SQLItem {
    static func getTable() -> SQLite.Table {
        return TBLAuthToken.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TBLAuthToken.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> AuthToken {
        return try TBLAuthToken.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> AuthToken {
        return try TBLAuthToken.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TBLAuthToken.toRow(self)
    }
    
    internal init(id: UUID, user: UUID, deviceName: String? = nil, location: String? = nil, token: String, refreshToken: String, createdAt: Date, updatedAt: Date, expiresAt: Date) {
        self.id = id
        self.user = user
        self.deviceName = deviceName
        self.location = location
        self.token = token
        self.refreshToken = refreshToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
    
    var id: UUID
    var user: UUID
    var deviceName: String?
    var location: String?
    var token: String
    var refreshToken: String
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date

}
 
class TBLAuthToken {
    static let table = Table("auth_token")
    
    static let id = Connection.id
    static let user = Expression<UUID>("user")
    static let deviceName = Expression<String?>("device_name")
    static let location = Expression<String?>("location")
    static let token = Expression<String>("token")
    static let refreshToken = Expression<String>("refresh_token")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Connection.updatedAt
    static let expiresAt = Expression<Date>("expires_at")
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(user)
            t.column(deviceName)
            t.column(location)
            t.column(token)
            t.column(refreshToken)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(expiresAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> AuthToken {
        let result = AuthToken(
            id: try row.get(id),
            user: try row.get(user),
            deviceName: try row.get(deviceName),
            location: try row.get(location),
            token: try row.get(token),
            refreshToken: try row.get(refreshToken),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt),
            expiresAt: try row.get(expiresAt))
        return result
    }
    
    static func toRow(_ item:AuthToken) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.user <- item.user,
                self.deviceName <- item.deviceName,
                self.location <- item.location,
                self.token <- item.token,
                self.refreshToken <- item.refreshToken,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt,
                self.expiresAt <- item.expiresAt]
    }
    
    static func first(_ con:Connection, token:String) throws -> AuthToken? {
        return try con.first(AuthToken.self, predicate: self.token == token)
    }
    
    static func first(_ con:Connection, refreshToken:String) throws -> AuthToken? {
        return try con.first(AuthToken.self, predicate: self.refreshToken == refreshToken)
    }
}


