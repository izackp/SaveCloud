//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/30/24.
//

import Vapor

struct ValidationIterator<T : IValidate> : IteratorProtocol, Sequence {
    var index:Int = 0
    var target:T
    mutating func next() -> String? {
        return target.iterateErrors(&index)
    }
    
    typealias Element = String
}

protocol IValidate {
    func iterateErrors(_ index:inout Int) -> String?
}

extension IValidate {
    func makeErrorIterator() -> ValidationIterator<Self> {
        return ValidationIterator(target: self)
    }
    
    func firstError() -> String? {
        var index = 0
        return self.iterateErrors(&index)
    }
    
    func listErrors() -> [String] {
        var index = 0
        guard let firstError = self.iterateErrors(&index) else { return [] }
        
        var listErrors = [firstError]
        while let error = self.iterateErrors(&index) {
            listErrors.append(error)
        }
        return listErrors
    }
    
    func checkValdiation() throws {
        var errors = listErrors()
        if (errors.count > 0) {
            throw Abort(.badRequest, reason: errors.joined(separator: "\n"))
        }
    }
}
