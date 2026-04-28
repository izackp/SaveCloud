//
//  SQLItem.swift
//
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import GRDB

protocol SQLItem: FetchableRecord, MutablePersistableRecord, TableRecord {
    var updatedAt: Date { get }
}
