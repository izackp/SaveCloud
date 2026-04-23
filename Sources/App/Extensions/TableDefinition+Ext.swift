//
//  TableDefinition+Ext.swift
//  SaveCloud
//
//  Created by Isaac Paul on 4/23/26.
//

import GRDB

public extension TableDefinition {
    
    @discardableResult
    public func column(_ col: Column, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        return self.column(col.name, type)
    }
    
    @discardableResult
    public func column(_ col: CodingKey, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        return self.column(col.stringValue, type)
    }
}
