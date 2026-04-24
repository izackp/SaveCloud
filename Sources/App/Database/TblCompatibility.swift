//
//  TblCompatibility.swift
//
//
//  Created by Isaac Paul on 4/24/26.
//

import GRDB
import Vapor

struct Compatibility: Codable, Content, SQLItem, Identifiable, Sendable {
    var id: UUID
    var notes: String?
    var updatedAt: Date

    init(id: UUID, notes: String? = nil, updatedAt: Date) {
        self.id = id
        self.notes = notes
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case notes
        case updatedAt = "updated_at"
    }

    static var databaseTableName: String {
        "compatibility"
    }

    static let id = Column(CodingKeys.id)
    static let notes = Column(CodingKeys.notes)
    static let updated_at = Column(CodingKeys.updatedAt)

    static func createTable(db: GRDB.Database) throws {
        if try db.tableExists(databaseTableName) {
            return
        }

        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(notes, .text)
            t.column(updated_at, .date).notNull()
        }
    }
}
