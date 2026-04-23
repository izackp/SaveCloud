//
//  TableDefinition+Ext.swift
//  SaveCloud
//
//  Created by Isaac Paul on 4/23/26.
//

import GRDB

public extension TableDefinition {
    
    @discardableResult
    func column(_ col: Column, _ type: GRDB.Database.ColumnType? = nil) -> ColumnDefinition {
        return self.column(col.name, type)
    }
    
    @discardableResult
    func column(_ col: CodingKey, _ type: GRDB.Database.ColumnType? = nil) -> ColumnDefinition {
        return self.column(col.stringValue, type)
    }
}
