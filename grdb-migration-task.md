# GRDB Migration Task

You are working in a Vapor 4 / Swift 6 project at /Users/isaacpaul/Projects/swift-projects/SaveCloud/SaveCloud.

## Goal
Complete a partial migration from SQLite.swift to GRDB, then fix all build errors so `swift build` succeeds.

## First Step
Create and check out branch `claude/grdb-migration` from main.

## Context

The codebase is mid-migration from SQLite.swift to GRDB. The project only has GRDB as a dependency (no SQLite.swift in Package.swift). Several files still reference SQLite.swift types (`SQLite.Connection`, `SQLite.Table`, `SQLite.Expression`, `SQLite.Row`, `SQLite.Setter`) that no longer exist. Additionally, a `Database` wrapper class that the entire codebase calls (`Database.getConnection()`, `Database.initDB()`) does not exist anywhere.

**Files already migrated to GRDB (use these as the pattern):**
- `Sources/App/Database/TblUser.swift` — `User` model uses GRDB `Column`, `db.create(table:)`, `db.tableExists()`
- `Sources/App/Database/TblSession.swift` — `AuthSession` uses the same GRDB pattern
- `Sources/App/Database/TblUserProfile.swift` — `UserProfile` same
- `Sources/App/Database/DBInfo.swift` — uses `FetchableRecord`, `PersistableRecord`, `TableRecord`

## Files to Write/Fix

### 1. `Sources/App/Database/Database.swift` (create new)
A simple class `Database` with two static methods:
- `initDB()` — delegates to `DBShared.initDB()`
- `getConnection(_ existing: DatabasePool? = nil) throws -> DatabasePool` — returns the existing pool or `DBShared.pool()`

### 2. `Sources/App/Database/Sqlite.swift` (fix)
Two bugs plus structural changes:
- `self.pool = pool` should assign to the static var `POOL`
- `createAllTables` and `dropAllTables` currently call `db.run(SomeClass.createQuery())` where `createQuery()` returns a `String` — this is not a GRDB API method. Change them to call `SomeModel.createTable(db: db)` following the pattern already used by `User`, `AuthSession`, `UserProfile`. You will need to add `createTable(db:)` to the models that don't have it yet (`GameMeta`, `GameHash`, `Save`) as part of migrating those files.
- `dropAllTables` uses `try?` — make it properly throwing.
- Add `Save` to both `createAllTables` and `dropAllTables` (currently missing).

### 3. `Sources/App/Database/SqliteItem.swift` (rewrite)
Currently entirely commented out. Rewrite it with:
- A `SQLItem` protocol that composes GRDB's `FetchableRecord`, `MutablePersistableRecord`, `TableRecord`, and requires `var id: UUID { get set }` and `var updatedAt: Date { get }`.
- An extension on `DatabasePool` providing convenience methods callers use throughout the codebase:
  - `insert(_ type:, item:)`
  - `insertWithRetry(_ type:, item:)` — retries with a new UUID on SQLITE_CONSTRAINT violation
  - `update(_ type:, item:)`
  - `upsert(_ type:, item:)`
  - `delete(_ type:, uuid:)`
  - `deleteAll(_ type:, predicate: SQLExpressible)`
  - `first(_ type:, uuid:)`
  - `first(_ type:, predicate: SQLExpressible)`
  - `fetchAll(_ type:)`
  - `fetchAll(_ type:, predicate: SQLExpressible)`
  - `count(_ type:)`
  - `count(_ type:, predicate: SQLExpressible)`
  - `updateField(_ type:, uuid:, columnName: String, value: DatabaseValueConvertible?)`
  - `transaction(_:)` — takes a throwing closure, runs inside a GRDB write transaction

### 4. `Sources/App/Database/TblGameHash.swift` (migrate)
- `GameHash` model: remove old `SQLItem` conformance with SQLite.swift types. Conform to the new GRDB-based `SQLItem`. Add `static var databaseTableName`. Implement `init(row: Row)` for `FetchableRecord`. Fields: `id`, `gameMetaId`, `hashedFileName`, `xxhash64`, `createdAt`, `updatedAt`.
- `TBLGameHash`: remove `Expression<T>` columns, replace with GRDB `Column` definitions.
- Add `GameHash.createTable(db: GRDB.Database) throws` (table DDL, check `tableExists` first).
- Port methods to GRDB: `fetchList(gameMetaId:existingCon:)`, `first(_:uuid:)`, `first(_:hash:)`, `replaceGameMeta(_:targetUUID:replaceWith:)`.

### 5. `Sources/App/Database/TblGameMeta.swift` (migrate)
Same pattern as TblGameHash. Additional notes:
- `fetchPaged` uses `QueryType` (SQLite.swift-only) — use GRDB's `QueryInterfaceRequest<GameMeta>` instead.
- Port `replaceBaseGameId`.
- Keep `GameMetaCreate` as-is (Vapor `Content` struct, no DB changes needed).

### 6. `Sources/App/Database/TblSaves.swift` (migrate)
Same pattern. Notes:
- `TblSave.id` and `TblSave.updatedAt` currently reference `Connection.id`/`Connection.updatedAt` from old SqliteItem.swift — replace with GRDB `Column` definitions.
- Port `fetchPaged` (two overloads), `deleteAll`, `fetchAllGameIds`.

### 7. `Sources/App/UserAuthentication.swift` (fix)
- `createSession` has a parameter `_ connection: Connection` — change `Connection` to `DatabasePool`.

### 8. `Sources/App/Web/API/v1/Login.swift` (fix)
- `connection.updateField(AuthSession.self, uuid: sessionId, setter: TBLSession.refreshToken <- newRefreshToken)` uses SQLite.swift `<-` setter syntax. Update the call to match the `updateField(columnName:value:)` signature defined in SqliteItem.swift.

## Constraints
- Use GRDB standard UUID storage (blob). GRDB handles `UUID` natively as `DatabaseValueConvertible`.
- All models keep their `CodingKeys` for JSON responses. Implement `FetchableRecord`'s `init(row:)` manually to map GRDB row columns to Swift property names using `CodingKeys`.
- Swift 6 strict concurrency is enabled — use `nonisolated(unsafe)` for static mutable state, matching the pattern in existing files.
- Run `swift build` after making all changes. Fix any remaining errors until the build succeeds.
- Commit footer format: `Automated-By: claude-sonnet-4-6` (no Co-Authored-By line).
- Commit only after `swift build` succeeds.
