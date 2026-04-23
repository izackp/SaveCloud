//
//  TblSession.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import Vapor
import GRDB

final class AuthSession: Content, Codable, SessionAuthenticatable, SQLItem {
    public var sessionID: UUID { id }
    
    typealias SessionID = UUID
    
    var id: UUID
    var refreshToken: UUID?
    var user: UUID
    var deviceName: String?
    var location: String?
    var ipAddress: String
    var isAdmin: Bool
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date
    
    public init(id: UUID, refreshToken: UUID?, user: UUID, deviceName: String? = nil, location: String? = nil, ipAddress:String, isAdmin: Bool, createdAt: Date, updatedAt: Date, expiresAt: Date) {
        self.id = id
        self.refreshToken = refreshToken
        self.user = user
        self.deviceName = deviceName
        self.location = location
        self.createdAt = createdAt
        self.ipAddress = ipAddress
        self.isAdmin = isAdmin
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case refreshToken = "refresh_token"
        case user
        case deviceName = "device_name"
        case location
        case ipAddress = "ip_address"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
    
    func isExpired(leeway: TimeInterval = 60) -> Bool {
        if (Date() + leeway < self.expiresAt) {
            return false
        }
        return true
    }
}
 
extension AuthSession {
    
    //MARK: - DATABASE
    static var databaseTableName: String { get {
        return "session"
    } }
    
    static let id               = Column(AuthSession.CodingKeys.id)
    static let refresh_token    = Column(AuthSession.CodingKeys.refreshToken)
    static let user             = Column(AuthSession.CodingKeys.user)
    static let device_name      = Column(AuthSession.CodingKeys.deviceName)
    static let location         = Column(AuthSession.CodingKeys.location)
    static let ip_address       = Column(AuthSession.CodingKeys.ipAddress)
    static let is_admin         = Column(AuthSession.CodingKeys.isAdmin)
    static let created_at       = Column(AuthSession.CodingKeys.createdAt)
    static let updated_at       = Column(AuthSession.CodingKeys.updatedAt)
    static let expires_at       = Column(AuthSession.CodingKeys.expiresAt)
    
    static func createTable(db:GRDB.Database) throws {
        if (try db.tableExists(databaseTableName)) {
            return
        }
        
        
        try db.create(table: databaseTableName) { t in
            t.column(id,                .blob).primaryKey()
            t.column(refresh_token,     .text)
            t.column(user,              .text).notNull()
            t.column(device_name,       .text)
            t.column(location,          .text)
            t.column(ip_address,        .text).notNull()
            t.column(is_admin,          .boolean).notNull()
            t.column(created_at,        .date).notNull()
            t.column(updated_at,        .date).notNull()
            t.column(expires_at,        .date).notNull()
        }
    }

    init(row: Row) {
        id = row[Self.id]
        refreshToken = row[Self.refresh_token]
        user = row[Self.user]
        deviceName = row[Self.device_name]
        location = row[Self.location]
        ipAddress = row[Self.ip_address]
        isAdmin = row[Self.is_admin]
        createdAt = row[Self.created_at]
        updatedAt = row[Self.updated_at]
        expiresAt = row[Self.expires_at]
    }

    static func first(_ con: DatabasePool, uuid: UUID) throws -> AuthSession? {
        try con.first(AuthSession.self, uuid: uuid)
    }
}

typealias TBLSession = AuthSession

