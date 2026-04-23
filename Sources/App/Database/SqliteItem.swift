//
//  SQLItem.swift
//
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import GRDB

protocol SQLItem: FetchableRecord, MutablePersistableRecord, TableRecord {
    var id: UUID { get set }
    var updatedAt: Date { get }
}

extension DatabasePool {
    func insert<T>(_ type: T.Type, item: T) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            var item = item
            try item.insert(db)
        }
    }

    func insertWithRetry<T>(_ type: T.Type, item: T) throws -> UUID? where T: SQLItem {
        try unsafeReentrantWrite { db in
            var item = item
            do {
                try item.insert(db)
                return nil
            } catch let error as DatabaseError
                where error.extendedResultCode.primaryResultCode == .SQLITE_CONSTRAINT
            {
                // UUID collisions should be rare, but callers expect a retry path here.
                for _ in 0..<5 {
                    item.id = UUID()
                    do {
                        try item.insert(db)
                        return item.id
                    } catch let retryError as DatabaseError
                        where retryError.extendedResultCode.primaryResultCode == .SQLITE_CONSTRAINT
                    {
                        continue
                    }
                }
                throw AppError("Unable to generate unique id")
            }
        }
    }

    func update<T>(_ type: T.Type, item: T) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            var item = item
            try item.update(db)
        }
    }

    func upsert<T>(_ type: T.Type, item: T) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            var item = item
            try item.upsert(db)
        }
    }

    func delete<T>(_ type: T.Type, item: T) throws where T: SQLItem {
        try delete(type, uuid: item.id)
    }

    func delete<T>(_ type: T.Type, uuid: UUID) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            _ = try type.filter(Column("id") == uuid).deleteAll(db)
        }
    }

    func deleteAll<T>(_ type: T.Type, predicate: any SQLExpressible) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            _ = try type.filter(predicate.sqlExpression).deleteAll(db)
        }
    }

    func first<T>(_ type: T.Type, uuid: UUID) throws -> T? where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.filter(Column("id") == uuid).fetchOne(db)
        }
    }

    func first<T>(_ type: T.Type, predicate: any SQLExpressible) throws -> T? where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.filter(predicate.sqlExpression).fetchOne(db)
        }
    }

    func fetchAll<T>(_ type: T.Type) throws -> [T] where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.fetchAll(db)
        }
    }

    func fetchAll<T>(_ type: T.Type, predicate: any SQLExpressible) throws -> [T] where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.filter(predicate.sqlExpression).fetchAll(db)
        }
    }

    func count<T>(_ type: T.Type) throws -> Int where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.fetchCount(db)
        }
    }

    func count<T>(_ type: T.Type, predicate: any SQLExpressible) throws -> Int where T: SQLItem {
        try unsafeReentrantWrite { db in
            try type.filter(predicate.sqlExpression).fetchCount(db)
        }
    }

    func updateField<T>(
        _ type: T.Type,
        uuid: UUID,
        columnName: String,
        value: (any DatabaseValueConvertible)?
    ) throws where T: SQLItem {
        try unsafeReentrantWrite { db in
            _ = try type
                .filter(Column("id") == uuid)
                .updateAll(
                    db,
                    Column(columnName).set(to: value),
                    Column("updated_at").set(to: Date())
                )
        }
    }

    func transaction(_ updates: @escaping () throws -> Void) throws {
        try unsafeReentrantWrite { db in
            try db.inTransaction {
                try updates()
                return .commit
            }
        }
    }
}
