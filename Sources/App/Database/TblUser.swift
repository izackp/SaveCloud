//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import GRDB
import Vapor

final class AuthenticatedUser {

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

final class PublicUser: Codable, Content, IValidate {

    var id: UUID
    var username: String
    var email: String?
    var isAdmin: Bool
    var createdAt: Date
    var updatedAt: Date
    
    public init(id: UUID, username:String, email: String? = nil, isAdmin:Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func iterateErrors(_ index:inout Int) -> String? {
        switch index {
            case 0:
                index += 1
                if username.isEmpty {
                    return "Username is empty"
                }
                fallthrough
            case 1:
                index += 1
                if email?.isEmpty ?? true {
                    return "Email is empty"
                }
                fallthrough
            default:
                return nil
        }
    }
}

final class User: Content, Codable, SQLItem {

    var id: UUID
    var username: String
    var email: String?
    var passwordHash: String?
    var isAdmin: Bool
    var createdAt: Date
    var updatedAt: Date
    
    public init(id: UUID, username:String, email: String? = nil, passwordHash: String? = nil, isAdmin:Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case passwordHash = "password_hash"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toPublicUser() -> PublicUser {
        return PublicUser(id: id, username: username, email: email, isAdmin: isAdmin, createdAt: createdAt, updatedAt: updatedAt)
    }
    
    //MARK: - DATABASE
    static var databaseTableName: String { get {
        return "user"
    } }
    
    static let id               = Column(User.CodingKeys.id)
    static let username         = Column(User.CodingKeys.username)
    static let email            = Column(User.CodingKeys.email)
    static let password_hash    = Column(User.CodingKeys.passwordHash)
    static let is_admin         = Column(User.CodingKeys.isAdmin)
    static let created_at       = Column(User.CodingKeys.createdAt)
    static let updated_at       = Column(User.CodingKeys.updatedAt)
    
    static func createTable(db: GRDB.Database) throws {
        if (try db.tableExists(databaseTableName)) {
            return
        }
        
        try db.create(table: databaseTableName) { t in
            t.column(id,                .blob).primaryKey()
            t.column(username,          .text).notNull()
            t.column(email,             .text).notNull()
            t.column(password_hash,     .text).notNull()
            t.column(is_admin,          .boolean).notNull()
            t.column(created_at,        .date).notNull()
            t.column(updated_at,        .date).notNull()
        }
    }

    convenience init(row: Row) {
        self.init(
            id: row[Self.id],
            username: row[Self.username],
            email: row[Self.email],
            passwordHash: row[Self.password_hash],
            isAdmin: row[Self.is_admin],
            createdAt: row[Self.created_at],
            updatedAt: row[Self.updated_at])
    }

    static func first(_ con: DatabasePool, emailOrUsername: String) throws -> User? {
        try con.first(User.self, predicate: username == emailOrUsername || email == emailOrUsername)
    }
}

typealias TblUser = User
