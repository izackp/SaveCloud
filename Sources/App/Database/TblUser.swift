//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import SQLite
import Vapor

public struct AuthenticatedUser {

    public let id: UUID
    public let userId: UUID
    
    public init(
        id: UUID,
        userId: UUID
    ) {
        self.id = id
        self.userId = userId
    }
}

extension AuthenticatedUser: SessionAuthenticatable {
    public var sessionID: UUID { id }
}

final class User: Content, SQLItem, Authenticatable {
    
    static func authenticator() -> AsyncAuthenticator {
        UserTokenAuthenticator()
    }
    
    static func getTable() -> SQLite.Table {
        return TblUser.table
    }
    
    static func upsertConflictColumn() -> SQLite.Expressible {
        return TblUser.id
    }
    
    static func toItem(_ row: SQLite.Row) throws -> User {
        return try TblUser.toItem(row)
    }
    
    static func toItemFull(_ con: SQLite.Connection, _ row: SQLite.Row) throws -> User {
        return try TblUser.toItem(row)
    }
    
    func toRow() -> [SQLite.Setter] {
        TblUser.toRow(self)
    }
    
    init(id: UUID, username:String, email: String? = nil, passwordHash: String? = nil, isAdmin:Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var id: UUID
    var username: String
    var email: String?
    var passwordHash: String?
    var isAdmin: Bool
    var createdAt: Date
    var updatedAt: Date
}

class TblUser {
    static let table = Table("user")
    
    static let id = Connection.id
    static let username = Expression<String>("username")
    static let email = Expression<String?>("email")
    static let passwordHash = Expression<String?>("password_hash")
    static let isAdmin = Expression<Bool>("isAdmin")
    static let createdAt = Expression<Date>("created_at")
    static let updatedAt = Connection.updatedAt
    
    static func createQuery() -> String {
        return table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(username)
            t.column(email)
            t.column(passwordHash)
            t.column(isAdmin)
            t.column(createdAt)
            t.column(updatedAt)
        }
    }
    
    static func toItem(_ row:Row) throws -> User {
        let result = User(
            id: try row.get(id),
            username: try row.get(username),
            email: try row.get(email),
            passwordHash: try row.get(passwordHash),
            isAdmin: try row.get(isAdmin),
            createdAt: try row.get(createdAt),
            updatedAt: try row.get(updatedAt))
        return result
    }
    
    static func toRow(_ item:User) -> [SQLite.Setter] {
        return [self.id <- item.id,
                self.username <- item.username,
                self.email <- item.email,
                self.passwordHash <- item.passwordHash,
                self.isAdmin <- item.isAdmin,
                self.createdAt <- item.createdAt,
                self.updatedAt <- item.updatedAt]
    }
    
    static func first(_ con:Connection, email:String) throws -> User? {
        return try con.first(User.self, predicate: self.email == email)
    }
    
    static func first(_ con:Connection, emailOrUsername:String) throws -> User? {
        let result = try con.first(User.self, predicate: self.email == email)
        if (result == nil) {
            return try con.first(User.self, predicate: self.username == emailOrUsername)
        }
        return result
    }
}


