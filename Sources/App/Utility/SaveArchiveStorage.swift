import Foundation
import Vapor

enum SaveArchiveStorage {
    private static let directoryName = "save-archives"
    private static let pendingDirectoryName = "pending-save-archives"

    static func archiveDirectory() throws -> URL {
        try directory(for: directoryName)
    }

    static func pendingDirectory() throws -> URL {
        try directory(for: pendingDirectoryName)
    }

    static func finalArchivePath(saveId: UUID) throws -> URL {
        try archiveDirectory().appendingPathComponent("\(saveId.uuidString).zip")
    }

    static func pendingArchivePath(storageKey: String) throws -> URL {
        try pendingDirectory().appendingPathComponent("\(storageKey).upload")
    }

    private static func directory(for component: String) throws -> URL {
        let rootPath = DBShared.path
        guard !rootPath.isEmpty else {
            throw AppError("Database path not initialized.")
        }
        let url = URL(fileURLWithPath: rootPath, isDirectory: true).appendingPathComponent(component, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func movePendingArchive(storageKey: String, toSaveId saveId: UUID) throws -> URL {
        let source = try pendingArchivePath(storageKey: storageKey)
        let destination = try finalArchivePath(saveId: saveId)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path()) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: source, to: destination)
        return destination
    }

    static func removeIfExists(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
