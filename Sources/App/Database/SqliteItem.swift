//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import SQLite

protocol SQLItem {
    //associatedtype IdType:Value = UInt64 where IdType.Datatype : Equatable
    var id:UUID {
        get
    }
    
    var updatedAt:Date {
        get
    }
    
    static func getTable() -> Table
    static func upsertConflictColumn() -> Expressible
    static func toItem(_ row:Row) throws -> Self
    static func toItemFull(_ con:Connection, _ row:Row) throws -> Self
    
    func toRow() -> [Setter]
}

extension ExpressionType {
    public func order(asc:Bool) -> Expressible {
        if (asc) {
            return self.asc
        } else {
            return self.desc
        }
    }
}

extension Connection {
    
    //static let unique_id = Expression<Int64>("unique_id")
    
    func fetchAll<T>(_ type: T.Type) throws -> [T] where T : SQLItem {
        let table = type.getTable()
        let rowIterator = try self.prepareRowIterator(table)
        let list:[T] = try rowIterator.map({ return try type.toItemFull(self, $0) })
        return list
    }
    
    func delete<T>(_ type: T.Type, item:T) throws where T : SQLItem {
        try delete(type, uuid: item.id)
    }
    /*
    func first<T>(_ type: T.Type, uniqueId:Int64) throws -> T? where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.unique_id == uniqueId)
        if let row = try self.pluck(filter) {
            return try type.toItemFull(self, row)
        }
        return nil
    }
    
    func delete<T>(_ type: T.Type, uniqueId:Int64) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.unique_id == uniqueId)
        let query = filter.delete()
        try self.run(query)
    }
    
    func updateField<T>(_ type: T.Type, uniqueId:Int64, setter:Setter) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.unique_id == uniqueId)
        let query = filter.update(setter)
        try self.run(query)
    }*/
    
    //update, upsert, and insert doesn't support sub-objects..
    func update<T>(_ type: T.Type, item:T) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.id == item.id)
        let query = filter.update(item.toRow())
        try self.run(query)
    }
    
    func upsert<T>(_ type: T.Type, item:T) throws where T : SQLItem {
        let table = type.getTable()
        let query = table.upsert(item.toRow(), onConflictOf: type.upsertConflictColumn())
        try self.run(query)
    }
    
    func insert<T>(_ type: T.Type, item:T) throws where T : SQLItem {
        let table = type.getTable()
        let query = table.insert(item.toRow())
        try self.run(query)
    }
    
    func first<T>(_ type: T.Type, predicate:Expression<Bool>) throws -> T? where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        if let row = try self.pluck(filter) {
            return try type.toItemFull(self, row)
        }
        return nil
    }
    
    func first<T>(_ type: T.Type, predicate:Expression<Bool?>) throws -> T? where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        if let row = try self.pluck(filter) {
            return try type.toItemFull(self, row)
        }
        return nil
    }
    
    func filter<T>(_ type: T.Type, predicate:Expression<Bool>) throws -> [T] where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let rowIterator = try self.prepareRowIterator(filter)
        let list:[T] = try rowIterator.map({ return try type.toItemFull(self, $0) })
        return list
    }
    
    func fetchAll<T>(_ type: T.Type, predicate:Expression<Bool>) throws -> [T] where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let rowIterator = try self.prepareRowIterator(filter)
        let list:[T] = try rowIterator.map({ return try type.toItemFull(self, $0) })
        return list
    }
    
    func fetchAll<T>(_ type: T.Type, predicate:Expression<Bool?>) throws -> [T] where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let rowIterator = try self.prepareRowIterator(filter)
        let list:[T] = try rowIterator.map({ return try type.toItemFull(self, $0) })
        return list
    }
    
    func fetchPaged<T>(_ type: T.Type, _ pageInfo:PageInfo, predicate:Expression<Bool>) throws -> [T] where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let asc = pageInfo.sortByAscending
        let sorted = switch (pageInfo.sortBy) {
            case .id:
                filter.order(Connection.id.order(asc: asc))
            case .createdAt:
                filter.order(Connection.createdAt.order(asc: asc))
            case .updatedAt:
                filter.order(Connection.updatedAt.order(asc: asc))
            case .date:
                filter.order(Connection.updatedAt.order(asc: asc)) //TODO: Deceptful we don't support this
        }
        let rowIterator = try self.prepareRowIterator(sorted)
        let list:[T] = try rowIterator.map({ return try type.toItemFull(self, $0) })
        return list
    }
    
    func deleteAll<T>(_ type: T.Type, predicate:Expression<Bool>) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let query = filter.delete()
        try self.run(query)
    }
    
    func deleteAll<T>(_ type: T.Type, predicate:Expression<Bool?>) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let query = filter.delete()
        try self.run(query)
    }
}

extension Connection {
    static let id = Expression<UUID>("id")
    static let updatedAt = Expression<Date>("updated_at")
    static let createdAt = Expression<Date>("created_at")
    
    func count<T>(_ type: T.Type) throws -> Int where T : SQLItem {
        let table = type.getTable()
        let count = try self.scalar(table.count)
        return count
    }
    
    func count<T>(_ type: T.Type, predicate:Expression<Bool>) throws -> Int where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let count = try self.scalar(filter.count)
        return count
    }
    
    func count<T>(_ type: T.Type, predicate:Expression<Bool?>) throws -> Int where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(predicate)
        let count = try self.scalar(filter.count)
        return count
    }
    
    func first<T>(_ type: T.Type, uuid:UUID) throws -> T? where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.id == uuid)
        if let row = try self.pluck(filter) {
            return try type.toItemFull(self, row)
        }
        return nil
    }
    
    func delete<T>(_ type: T.Type, uuid:UUID) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.id == uuid)
        let query = filter.delete()
        try self.run(query)
    }
    
    func updateField<T>(_ type: T.Type, uuid:UUID, setter:Setter) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.id == uuid)
        let query = filter.update(setter, Connection.updatedAt <- Date())
        try self.run(query)
    }
    
    //update, upsert, and insert doesn't support sub-objects..
    func updateS<T>(_ type: T.Type, item:T) throws where T : SQLItem {
        let table = type.getTable()
        let filter = table.filter(Connection.id == item.id)
        let query = filter.update(item.toRow())
        try self.run(query)
    }
}
