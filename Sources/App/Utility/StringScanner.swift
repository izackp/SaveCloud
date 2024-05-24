//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/10/24.
//

import Foundation

extension StringProtocol {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
    
    subscript (r: ClosedRange<Int>) -> SubSequence {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        let range = start ... end
        return self[range]
    }
    
    func index(offset: Int) -> Index {
        return self.index(startIndex, offsetBy: offset)
    }
    
    func substring(from: Int) -> SubSequence {
        let fromIndex = index(offset: from)
        return self[fromIndex...]
    }
    
    func substring(to: Int) -> SubSequence {
        let toIndex = index(offset: to)
        return self[..<toIndex]
    }
    
}

extension CharacterSet {
    func containsUnicodeScalars(of character: Character) -> Bool {
        return character.unicodeScalars.allSatisfy(contains(_:))
    }
}

final class StringScannerError: LocalizedError, Sendable {
    
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    init(_ message: String, _ error:Error) {
        self.message = "\(message) : \(error.localizedDescription)"
    }
    
    static func failure<T>(_ message: String) -> Result<T, StringScannerError> {
        return .failure(StringScannerError(message))
    }
    
    var errorDescription: String? {
        get {
            return message
        }
    }
}

public struct StringScanner {
    public init(span: Substring, pos: Int, dir: Int) {
        self.span = span
        self.pos = pos
        self.dir = dir
    }
    
    let span:Substring
    public var pos:Int
    var dir:Int
    
    public func checkPos() throws {
        if (pos < 0 || pos >= span.count) {
            throw StringScannerError("Current pos not in string: pos: \(pos) str: \(span)")
        }
    }
    
    public mutating func expect(c: Character) throws {
        try checkPos()
        let cAtPos = span[pos]
        if (cAtPos != c) {
            throw StringScannerError("Unexpected character: \(cAtPos) pos: \(pos) str: \(span)")
        }
        pos += dir
        return
    }
    
    public mutating func expect(set: CharacterSet) throws {
        try checkPos()
        let cAtPos = span[pos]
        if (set.containsUnicodeScalars(of: cAtPos) == false) {
            throw StringScannerError("Unexpected character: \(cAtPos) pos: \(pos) str: \(span)")
        }
        pos += dir
        return
    }
    
    public mutating func move(by: Int) -> Bool {
        let targetPos = pos + by
        if (targetPos < 0 || targetPos >= span.count) {
            return false
        }
        pos = targetPos
        return true
    }
    
    public mutating func skipAny(set: CharacterSet) {
        if (pos < 0 || pos >= span.count) {
            return
        }
        let start = pos
        let rStride:StrideThrough<Int>
        if (dir < 0) {
            rStride = stride(from:start, through:0, by:dir)
        } else {
            rStride = stride(from:start, through:span.count-1, by:dir)
        }
        for i in rStride {
            pos = i
            if (set.containsUnicodeScalars(of: span[i]) == false) {
                break
            }
        }
    }
    
    public mutating func read(maxChars:Int? = nil) throws -> Substring {
        try checkPos()
        let start = pos
        var total = 0
        //TODO: Simplify
        let rStride:StrideThrough<Int>
        if (dir < 0) {
            rStride = stride(from:start, through:0, by:dir)
        } else {
            rStride = stride(from:start, through:span.count-1, by:dir)
        }
        for i in rStride {
            pos = i
            if let maxChars = maxChars, (total >= maxChars) {
                break
            }
            total += 1
        }
        let endPos = pos
        if (dir < 0) {
            return span[endPos...start]
        }
        return span[start...endPos]
    }
    
    //Essentialy tries to consume a string to return. Pos stops at next character
    public mutating func readUntilMatch(set: CharacterSet, maxChars:Int) throws -> Substring {
        try checkPos()
        let start = pos
        var total = 0
        //Extra read for simpler code
        if (set.containsUnicodeScalars(of: span[start])) {
            throw StringScannerError("Unexpected character: \(span[start]) pos: \(pos) str: \(span)")
        }
        let rStride:StrideThrough<Int>
        if (dir < 0) {
            rStride = stride(from:start, through:0, by:dir)
        } else {
            rStride = stride(from:start, through:span.count-1, by:dir)
        }
        for i in rStride {
            pos = i
            if (set.containsUnicodeScalars(of: span[i]) || total >= maxChars) {
                break
            }
            total += 1
        }
        let endPos = pos - dir
        if (dir < 0) {
            return span[endPos...start]
        }
        return span[start...endPos]
    }
    
    public mutating func readUntilMatch(c: Character, maxChars:Int) throws -> Substring {
        let set = NSCharacterSet(charactersIn: String(c)) //TODO: Weird
        return try readUntilMatch(set: set as CharacterSet, maxChars: maxChars)
    }
    
    public mutating func readWhileMatching(set: CharacterSet, maxChars:Int) throws -> Substring {
        try checkPos()
        let start = pos
        var total = 0
        //Extra read for simpler code
        if (set.containsUnicodeScalars(of: span[start]) == false) {
            throw StringScannerError("Unexpected character: \(span[start]) pos: \(pos) str: \(span)")
        }
        let rStride:StrideThrough<Int>
        if (dir < 0) {
            rStride = stride(from:start, through:0, by:dir)
        } else {
            rStride = stride(from:start, through:span.count-1, by:dir)
        }
        for i in rStride {
            pos = i
            if (set.containsUnicodeScalars(of: span[i]) == false || total >= maxChars) {
                break
            }
            total += 1
        }
        let endPos = pos - dir
        if (dir < 0) {
            return span[endPos...start]
        }
        return span[start...endPos]
    }
    
    public mutating func readWhileMatching(c: Character, maxChars:Int) throws -> Substring {
        let set = NSCharacterSet(charactersIn: String(c)) //TODO: Weird
        return try readWhileMatching(set: set as CharacterSet, maxChars: maxChars)
    }
    
    let IntChars = CharacterSet(charactersIn: "-").union(CharacterSet.decimalDigits)
    //let Separators = CharacterSet(charactersIn: "-").union(CharacterSet.decimalDigits)

    //Ex: -2147483648
    public mutating func readInt32() throws -> Int32 {
        let strInt = try readWhileMatching(set: IntChars, maxChars: 11)//TODO: Double check
        guard let value = Int32(strInt) else {
            throw StringScannerError("Unable to parse int32 from str: \(strInt)")
        }
        return value
    }
    
    //4,294,967,295
    public mutating func readUInt32() throws -> UInt32 {
        let strInt = try readWhileMatching(set: CharacterSet.decimalDigits, maxChars: 10)
        guard let value = UInt32(strInt) else {
            throw StringScannerError("Unable to parse uint32 from str: \(strInt)")
        }
        return value
    }
    
    //-32767
    public mutating func readInt16() throws -> Int16 {
        let strInt = try readWhileMatching(set: IntChars, maxChars: 6)
        guard let value = Int16(strInt) else {
            throw StringScannerError("Unable to parse int16 from str: \(strInt)")
        }
        return value
    }
    
    //65535
    public mutating func readUInt16() throws -> UInt16 {
        let strInt = try readWhileMatching(set: CharacterSet.decimalDigits, maxChars: 5)
        guard let value = UInt16(strInt) else {
            throw StringScannerError("Unable to parse uint16 from str: \(strInt)")
        }
        return value
    }
    
    //18,446,744,073,709,551,615
    public mutating func readUInt64() throws -> UInt64 {
        let strInt = try readWhileMatching(set: CharacterSet.decimalDigits, maxChars: 20)
        guard let value = UInt64(strInt) else {
            throw StringScannerError("Unable to parse UInt64 from str: \(strInt)")
        }
        return value
    }
    
    //-9,223,372,036,854,775,807
    public mutating func readInt64() throws -> Int64 {
        let strInt = try readWhileMatching(set: IntChars, maxChars: 20)
        guard let value = Int64(strInt) else {
            throw StringScannerError("Unable to parse Int64 from str: \(strInt)")
        }
        return value
    }

}
