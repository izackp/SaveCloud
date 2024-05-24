//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation

final class AppError: LocalizedError, Sendable {
    
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    init(_ message: String, _ error:Error) {
        self.message = "\(message) : \(error.localizedDescription)"
    }
    
    static func failure<T>(_ message: String) -> Result<T, AppError> {
        return .failure(AppError(message))
    }
    
    var errorDescription: String? {
        get {
            return message
        }
    }
}
