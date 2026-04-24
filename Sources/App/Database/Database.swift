import Foundation
import GRDB
import CRLogging

// Offline == Stored on device; Not to get confused with offline jobs
// Online == Stored on server
// Local == properties that are only stored locally

class DBShared {
    static let fileName = "db.sqlite3"
    nonisolated(unsafe) static var path:String = ""
    static let version = 1
    
    static func initDB(clearDB:Bool = false) throws -> DBInfo  {
        guard let path_ = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first else { throw AppError("Document directory not found.")}
        path = path_
        
        let pool:DatabasePool
        do {
            let finalPath = "\(path)/\(fileName)"
            pool = try DatabasePool(path: finalPath)
            print("Path: \(pool.path)")
        } catch {
            let error = AppError("Unable to connect to database", error)
            logAndReportException(SourceInfo(type: #file), error)
            throw error
        }
        
        try pool.write() { db in
            if (clearDB) {
                try dropAllTables(db)
            }
            try createAllTables(db)
        }
        
        let globalInfo = try pool.read() { db in
            try DBInfo.fetchOne(db)
        }
        
        let finalInfo:DBInfo
        if let globalInfo = globalInfo {
            finalInfo = try migrateToLatestVersion(pool, globalInfo)
        } else {
            let newGlobalInfo = DBInfo(version: version)
            try pool.write { db in
                try newGlobalInfo.insert(db)
            }
            finalInfo = newGlobalInfo
        }
        
        logMessage(.info, "Create DB Successful")
        self.POOL = pool
        return finalInfo
    }

    private static func migrateToLatestVersion(_ pool: DatabasePool, _ globalInfo: DBInfo) throws -> DBInfo {
        globalInfo
    }

    private static func createAllTables(_ db: GRDB.Database) throws {
        try DBInfo.createTable(db: db)
        try User.createTable(db: db)
        try AuthSession.createTable(db: db)
        try GameMeta.createTable(db: db)
        try GameHash.createTable(db: db)
        try Save.createTable(db: db)
        try UserProfile.createTable(db: db)
    }

    private static func dropAllTables(_ db: GRDB.Database) throws {
        if try db.tableExists(DBInfo.databaseTableName) {
            try db.drop(table: DBInfo.databaseTableName)
        }
        if try db.tableExists(User.databaseTableName) {
            try db.drop(table: User.databaseTableName)
        }
        if try db.tableExists(AuthSession.databaseTableName) {
            try db.drop(table: AuthSession.databaseTableName)
        }
        if try db.tableExists(GameMeta.databaseTableName) {
            try db.drop(table: GameMeta.databaseTableName)
        }
        if try db.tableExists(GameHash.databaseTableName) {
            try db.drop(table: GameHash.databaseTableName)
        }
        if try db.tableExists(Save.databaseTableName) {
            try db.drop(table: Save.databaseTableName)
        }
        if try db.tableExists(UserProfile.databaseTableName) {
            try db.drop(table: UserProfile.databaseTableName)
        }
    }
    
    nonisolated(unsafe) static var POOL:DatabasePool? = nil
    public static func pool() -> DatabasePool {
        return POOL!
    }
}
