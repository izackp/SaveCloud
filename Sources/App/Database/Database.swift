import GRDB

final class Database {
    static func initDB() throws -> DBInfo {
        try DBShared.initDB()
    }

    static func getConnection(_ existing: DatabasePool? = nil) throws -> DatabasePool {
        existing ?? DBShared.pool()
    }
}
