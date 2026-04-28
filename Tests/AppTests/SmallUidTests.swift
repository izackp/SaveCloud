@testable import App
import Foundation
import XCTest

final class SmallUidTests: XCTestCase {
    func testSmallUidRoundTripsKnownRawValue() throws {
        let uid = SmallUid(rawValue: 0)
        XCTAssertEqual(uid.description, "AAAAAAAAAAA")

        let decoded = try SmallUid(base64URL: "AAAAAAAAAAA")
        XCTAssertEqual(decoded.rawValue, 0)
    }

    func testSmallUidEncodesTimestampAndRandomInto64Bits() throws {
        let uid = try SmallUid(timestamp: 0xABCDE, random: 0x54321)

        XCTAssertEqual(uid.timestamp, 0xABCDE)
        XCTAssertEqual(uid.random, 0x54321)
        XCTAssertEqual(uid.rawValue, (0xABCDE << 20) | 0x54321)
    }

    func testSmallUidAcceptsStrictBase64URLInput() throws {
        let original = try SmallUid(timestamp: 1_234_567, random: 0xABCDE)
        let decoded = try SmallUid(base64URL: original.description)
        XCTAssertEqual(decoded, original)
    }

    func testSmallUidAcceptsStandardBase64InSeparateInitializer() throws {
        let original = try SmallUid(timestamp: 1_234_567, random: 0xABCDE)
        let standardBase64 = Data(original.rawValue.bigEndianBytes).base64EncodedString()

        let decoded = try SmallUid(base64: standardBase64)
        XCTAssertEqual(decoded, original)
    }

    func testSmallUidRejectsBadInput() throws {
        XCTAssertThrowsError(try SmallUid(base64URL: "short")) { error in
            XCTAssertEqual(error as? SmallUidError, .notABase64URL)
        }
        XCTAssertThrowsError(try SmallUid(base64URL: "!!!!!!!!!!!")) { error in
            XCTAssertEqual(error as? SmallUidError, .invalidCharacter)
        }
        XCTAssertThrowsError(try SmallUid(base64URL: "AAAAAAAAAAA=")) { error in
            XCTAssertEqual(error as? SmallUidError, .notABase64URL)
        }
        XCTAssertThrowsError(try SmallUid(base64URL: "AAAAAAAAAA+")) { error in
            XCTAssertEqual(error as? SmallUidError, .invalidCharacter)
        }
    }

    func testSmallUidGeneratedValueUsesCurrentLayout() throws {
        let before = UInt64(Date().timeIntervalSince1970 * 1_000)
        let uid = SmallUid.generate()
        let after = UInt64(Date().timeIntervalSince1970 * 1_000)

        XCTAssertGreaterThanOrEqual(uid.timestamp, before)
        XCTAssertLessThanOrEqual(uid.timestamp, after)
        XCTAssertLessThanOrEqual(uid.random, SmallUid.maxRandom)
        XCTAssertEqual(uid.description.count, SmallUid.encodedLength)
    }
}
