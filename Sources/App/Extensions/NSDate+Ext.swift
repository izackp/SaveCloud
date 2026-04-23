//
//  NSDate+Ext.swift
//  SaveCloud
//
//  Created by Isaac Paul on 4/23/26.
//

import Foundation

//NOTE: Thread safe as of iOS 7
fileprivate let formatter = DateFormatter().apply {
    $0.locale = Locale(identifier: "en_US_POSIX")
    $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
}
//2020-10-22T17:55:43.213
fileprivate let formatterBackup = DateFormatter().apply {
    $0.locale = Locale(identifier: "en_US_POSIX")
    $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS" //No idea why, but the above code supports a space instead of a T, but this line does not!
}

public extension DateFormatter {
    func apply(toApply:(_ input:DateFormatter)->()) -> DateFormatter {
        toApply(self)
        return self
    }
}

public extension Date {
    
    func toString() -> String {
        return toStringMainThread()
    }
    
    func toStringMainThread() -> String {
        return formatter.string(from: self)
    }
    
    func toStringThreadSafe() -> String {
        let safeFormatter = DateFormatter().apply {
            $0.locale = Locale(identifier: "en_US_POSIX")
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        }
        return safeFormatter.string(from: self)
    }
}

public extension String {
    func toDate() -> Date? {
        return toDateMainThread()
    }
    
    func toDateBackup() -> Date? {
        return toDateBackupMainThread()
    }
    
    func toDateBackupMainThread() -> Date? {
        let spacesInsteadOfT = self.replacingOccurrences(of: " ", with: "T")
        return formatterBackup.date(from: spacesInsteadOfT)
    }
    
    func toDateMainThread() -> Date? {
        return formatter.date(from: self)
    }
    /* Sometimes returns null...
    func toDateThreadSafe() -> Date? {
        let safeFormatter = DateFormatter().apply {
            $0.locale = Locale(identifier: "en_US_POSIX")
            $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        }
        return safeFormatter.date(from: self)
    }*/
    
    func expectDate() throws -> Date {
        if let result = toDate() {
            return result
        }
        throw AppError("Unable to convert string to date: \(self)")
    }
}
