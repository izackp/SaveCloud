//
//  SQLite.swift
//
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation
import SQLite

// Offline == Stored on device; Not to get confused with offline jobs
// Online == Stored on server
// Local == properties that are only stored locally

class Database {
    static let fileName = "db.sqlite3"
    static var path:String = ""
    static func initDB() throws {
        guard let path_ = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first else { throw AppError("Document directory not found.")}
        path = path_
        
        let db = try getConnection()
        //try db.run(TblUser.table.drop())
        //try db.run(TBLSession.table.drop())
        //try db.run(TblUser.dropQuery())
        try db.run(TblUser.createQuery())
        try db.run(TBLSession.createQuery())
    }
    
    static func getConnection() throws -> Connection {
        do {
            return try Connection("\(path)/\(fileName)")
        } catch {
            throw AppError("Unable to connect to database", error)
        }
    }
}
