//
//  UserProfile.swift
//
//
//  Created by Isaac Paul on 6/28/24.
//

import GRDB
import Vapor

struct UserProfile : Codable, Content, SQLItem, Identifiable, Sendable {
    var id: SmallUid
    var userId: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    
    init(id: SmallUid, userId: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension UserProfile {
    //MARK: - DATABASE
    static var databaseTableName: String { get {
        return "user_profile"
    } }
    
    static let id            = Column(UserProfile.CodingKeys.id)
    static let user_id       = Column(UserProfile.CodingKeys.userId)
    static let name          = Column(UserProfile.CodingKeys.name)
    static let created_at    = Column(UserProfile.CodingKeys.createdAt)
    static let updated_at    = Column(UserProfile.CodingKeys.updatedAt)
    
    static func createTable(db: GRDB.Database) throws {
        if (try db.tableExists(databaseTableName)) {
            return
        }
        
        try db.create(table: databaseTableName) { t in
            t.column(id,            .blob).primaryKey()
            t.column(user_id,       .blob).notNull()
            t.column(name,          .text).notNull()
            t.column(created_at,    .date).notNull()
            t.column(updated_at,    .date).notNull()
        }
    }
}
