//
//  DecoderUtil.swift
//  SaveCloud
//
//  Created by Isaac Paul on 4/23/26.
//

import Foundation
import CRLogging

public extension KeyedDecodingContainer where Key : CodingKey {
    
    func decodeDate(_ key: KeyedDecodingContainer<K>.Key) throws -> Date {
        let str = try self.decode(String.self, forKey: key)
        guard let date = str.toDate() else {
            //logAndReportError("Serialization Error: Can't map \(str) to date. Using Backup.")
            guard let date = str.toDateBackup() else {
                throw AppError("decodeDate Error: Can't map \(str) to date. Backup Failed.")
            }
            return date
        }
        return date
    }
    
    func decodeDateIfPresent(_ key: KeyedDecodingContainer<K>.Key) throws -> Date? {
        guard let str = try self.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let date = str.toDate() else {
            //logAndReportError("Serialization Error: Can't map \(str) to date. Using Backup.")
            guard let date = str.toDateBackup() else {
                throw AppError("decodeDateIfPresent Error: Can't map \(str) to date. Backup Failed.")
            }
            return date
        }
        return date
    }
    
}

public extension KeyedEncodingContainer where Key : CodingKey {
    
    mutating func encodeDate(_ value:Date, forKey: KeyedDecodingContainer<K>.Key) throws {
        let str = value.toString()
        try self.encode(str, forKey: forKey)
    }
    
    mutating func encodeDateOrNil(_ value:Date?, forKey: KeyedDecodingContainer<K>.Key) throws {
        let str = value?.toString()
        try self.encode(str, forKey: forKey)
    }
    
    mutating func encodeDateIfPresent(_ value:Date?, forKey: KeyedDecodingContainer<K>.Key) throws {
        if let str = value?.toString() {
            try self.encode(str, forKey: forKey)
        }
    }
    
}
