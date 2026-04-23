//
//  DBInfo.swift
//  SaveCloud
//
//  Created by Isaac Paul on 1/8/26.
//

import Foundation
import GRDB

public struct DBInfo : Sendable, Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let dateFormatterServer = DateFormatter().apply {
        $0.locale = Locale(identifier: "en_US_POSIX")
        $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    }
    public static let databaseDateDecodingStrategy = DatabaseDateDecodingStrategy.formatted(Self.dateFormatterServer)
    public static let databaseDateEncodingStrategy = DatabaseDateEncodingStrategy.formatted(Self.dateFormatterServer)
    
    public var id:UUID
    public var version:Int
    public var created_at:Date
    public var updated_at:Date
    
    public init(version:Int) {
        self.id = UUID.init()
        self.version = version
        
        let date = Date()
        self.created_at = date
        self.updated_at = date
    }
    
    public static var databaseTableName: String { get {
        return "global_info"
    } }
    
    public static let id                   = Column("id")
    public static let version              = Column("version")
    public static let created_at           = Column("created_at")
    public static let updated_at           = Column("updated_at")
    
    public static func createTable(db: GRDB.Database) throws {
        if (try db.tableExists(databaseTableName)) {
            return
        }
        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(version, .integer).notNull()
            
            t.column(created_at, .date).notNull()
            t.column(updated_at, .date).notNull()
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.version = try container.decode(Int.self, forKey: .version)
        self.created_at = try container.decodeDate(.created_at)
        self.updated_at = try container.decodeDate(.updated_at)
    }
    
    enum CodingKeys: CodingKey {
        case id
        case version
        case did_migrate
        case created_at
        case updated_at
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.version, forKey: .version)
        try container.encodeDate(self.created_at, forKey: .created_at)
        try container.encodeDate(self.updated_at, forKey: .updated_at)
    }
}
