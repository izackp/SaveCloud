import Foundation
import GRDB
import Vapor

struct PendingSaveUpload: Codable, Content, SQLItem, Identifiable, Sendable {
    var id: UUID
    var userId: SmallUid
    var profileId: SmallUid
    var gameHashId: UUID
    var gameMetaId: UUID?
    var compatibilityId: UUID
    var sequentialId: UUID
    var fileSize: Int
    var sourceDevice: String?
    var name: String?
    var contentHash: String
    var notes: String?
    var date: Date?
    var tempStorageKey: String
    var uploadCompletedAt: Date?
    var expiresAt: Date
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case profileId = "profile_id"
        case gameHashId = "game_hash_id"
        case gameMetaId = "game_meta_id"
        case compatibilityId = "compatibility_id"
        case sequentialId = "sequential_id"
        case fileSize = "file_size"
        case sourceDevice = "source_device"
        case name
        case contentHash = "content_hash"
        case notes
        case date
        case tempStorageKey = "temp_storage_key"
        case uploadCompletedAt = "upload_completed_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static var databaseTableName: String {
        "pending_save_upload"
    }

    static let id = Column(CodingKeys.id)
    static let user_id = Column(CodingKeys.userId)
    static let profile_id = Column(CodingKeys.profileId)
    static let game_hash_id = Column(CodingKeys.gameHashId)
    static let game_meta_id = Column(CodingKeys.gameMetaId)
    static let compatibility_id = Column(CodingKeys.compatibilityId)
    static let sequential_id = Column(CodingKeys.sequentialId)
    static let file_size = Column(CodingKeys.fileSize)
    static let source_device = Column(CodingKeys.sourceDevice)
    static let name = Column(CodingKeys.name)
    static let content_hash = Column(CodingKeys.contentHash)
    static let notes = Column(CodingKeys.notes)
    static let date = Column(CodingKeys.date)
    static let temp_storage_key = Column(CodingKeys.tempStorageKey)
    static let upload_completed_at = Column(CodingKeys.uploadCompletedAt)
    static let expires_at = Column(CodingKeys.expiresAt)
    static let created_at = Column(CodingKeys.createdAt)
    static let updated_at = Column(CodingKeys.updatedAt)

    static func createTable(db: GRDB.Database) throws {
        if try db.tableExists(databaseTableName) {
            return
        }

        try db.create(table: databaseTableName) { t in
            t.column(id, .blob).primaryKey()
            t.column(user_id, .blob).notNull()
            t.column(profile_id, .blob).notNull()
            t.column(game_hash_id, .blob).notNull()
            t.column(game_meta_id, .blob)
            t.column(compatibility_id, .blob).notNull()
            t.column(sequential_id, .blob).notNull()
            t.column(file_size, .integer).notNull()
            t.column(source_device, .text)
            t.column(name, .text)
            t.column(content_hash, .text).notNull()
            t.column(notes, .text)
            t.column(date, .date)
            t.column(temp_storage_key, .text).notNull()
            t.column(upload_completed_at, .date)
            t.column(expires_at, .date).notNull()
            t.column(created_at, .date).notNull()
            t.column(updated_at, .date).notNull()
        }
    }
}
