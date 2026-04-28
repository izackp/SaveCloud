import Foundation
import GRDB
import Vapor

public enum SmallUidError: Error, LocalizedError, Equatable {
    case timestampLimit
    case randomSizeLimit
    case notABase64URL
    case invalidCharacter
    case invalidByteCount

    public var errorDescription: String? {
        switch self {
        case .timestampLimit:
            return "TimestampLimit: Timestamp too large. Is it year 2528?"
        case .randomSizeLimit:
            return "RandomSizeLimit: Random number too large. How?"
        case .notABase64URL:
            return "NotABase64Url: Not a base64url string"
        case .invalidCharacter:
            return "InvalidChar: Invalid character"
        case .invalidByteCount:
            return "VecToArray: Failed to convert"
        }
    }
}

public struct SmallUid: Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral, LosslessStringConvertible, Codable, DatabaseValueConvertible {
    public static let timestampBitCount: UInt64 = 44
    public static let randomBitCount: UInt64 = 20
    public static let maxTimestamp: UInt64 = (1 << timestampBitCount) - 1
    public static let maxRandom: UInt64 = (1 << randomBitCount) - 1
    public static let encodedLength = 11

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: UInt64) {
        self.init(rawValue: value)
    }

    public init?(_ description: String) {
        try? self.init(base64URL: description)
    }

    public init() {
        self = Self.generate()
    }

    public init(timestamp: UInt64, random: UInt64) throws {
        guard timestamp <= Self.maxTimestamp else {
            throw SmallUidError.timestampLimit
        }
        guard random <= Self.maxRandom else {
            throw SmallUidError.randomSizeLimit
        }
        self.init(rawValue: (timestamp << Self.randomBitCount) | random)
    }

    public init(timestamp: UInt64) throws {
        try self.init(timestamp: timestamp, random: Self.randomValue())
    }

    public init(random: UInt64) throws {
        try self.init(timestamp: Self.currentTimestamp(), random: random)
    }

    public init(base64URL value: String) throws {
        guard value.count == Self.encodedLength else {
            throw SmallUidError.notABase64URL
        }
        guard value.allSatisfy({ character in
            switch character {
            case "A"..."Z", "a"..."z", "0"..."9", "-", "_":
                return true
            default:
                return false
            }
        }) else {
            throw SmallUidError.invalidCharacter
        }

        let standardBase64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            + "="

        try self.init(decodedBase64String: standardBase64, invalidLengthError: .notABase64URL)
    }

    public init(base64 value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == Self.encodedLength || trimmed.count == Self.encodedLength + 1 else {
            throw SmallUidError.notABase64URL
        }
        guard trimmed.allSatisfy({ character in
            switch character {
            case "A"..."Z", "a"..."z", "0"..."9", "+", "/", "=":
                return true
            default:
                return false
            }
        }) else {
            throw SmallUidError.invalidCharacter
        }

        let padded: String
        if trimmed.count == Self.encodedLength {
            padded = trimmed + "="
        } else {
            padded = trimmed
        }

        try self.init(decodedBase64String: padded, invalidLengthError: .notABase64URL)
    }

    private init(decodedBase64String value: String, invalidLengthError: SmallUidError) throws {
        guard let data = Data(base64Encoded: value) else {
            throw SmallUidError.notABase64URL
        }
        guard data.count == MemoryLayout<UInt64>.size else {
            throw invalidLengthError
        }

        let bytes = [UInt8](data)
        let value = bytes.withUnsafeBytes { $0.load(as: UInt64.self) }
        self.init(rawValue: UInt64(bigEndian: value))
    }

    public var timestamp: UInt64 {
        rawValue >> Self.randomBitCount
    }

    public var random: UInt64 {
        rawValue & Self.maxRandom
    }

    public var description: String {
        Data(rawValue.bigEndianBytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(base64URL: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public static func currentTimestamp() throws -> UInt64 {
        let milliseconds = UInt64(Date().timeIntervalSince1970 * 1_000)
        guard milliseconds <= maxTimestamp else {
            throw SmallUidError.timestampLimit
        }
        return milliseconds
    }

    public static func randomValue() -> UInt64 {
        UInt64.random(in: 0...maxRandom)
    }

    public static func generate() -> SmallUid {
        let timestamp = uncheckedCurrentTimestamp()
        let random = randomValue()
        return SmallUid(rawValue: (timestamp << randomBitCount) | random)
    }

    public static func < (lhs: SmallUid, rhs: SmallUid) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func uncheckedCurrentTimestamp() -> UInt64 {
        let milliseconds = UInt64(Date().timeIntervalSince1970 * 1_000)
        precondition(milliseconds <= maxTimestamp, SmallUidError.timestampLimit.localizedDescription)
        return milliseconds
    }
}

extension UInt64 {
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: bigEndian, Array.init)
    }
}

extension SmallUid {
    public var databaseValue: DatabaseValue {
        Data(rawValue.bigEndianBytes).databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> SmallUid? {
        guard let data = Data.fromDatabaseValue(dbValue),
              data.count == MemoryLayout<UInt64>.size else {
            return nil
        }
        let bytes = [UInt8](data)
        let value = bytes.withUnsafeBytes { $0.load(as: UInt64.self) }
        return SmallUid(rawValue: UInt64(bigEndian: value))
    }
}
