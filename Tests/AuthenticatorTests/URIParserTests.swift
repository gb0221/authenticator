import XCTest
@testable import Authenticator

final class URIParserTests: XCTestCase {
    func test_otpauth_basic_totp() {
        let uri = "otpauth://totp/Google:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Google"
        guard let (acc, secret) = OtpAuthURI.parse(uri) else {
            XCTFail("parse failed"); return
        }
        XCTAssertEqual(acc.issuer, "Google")
        XCTAssertEqual(acc.name, "alice@example.com")
        XCTAssertEqual(acc.type, .totp)
        XCTAssertEqual(acc.digits, 6)
        XCTAssertEqual(acc.period, 30)
        XCTAssertEqual(acc.algorithm, .sha1)
        // base32 "JBSWY3DPEHPK3PXP" decodes to "Hello!" + 0xde 0xad 0xbe 0xef = 10 bytes
        let expected: [UInt8] = [0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, 0xde, 0xad, 0xbe, 0xef]
        XCTAssertEqual(secret, Data(expected))
    }

    func test_otpauth_full_params() {
        let uri = "otpauth://totp/Acme%3Abob?secret=ORSXG5A&algorithm=SHA512&digits=8&period=60"
        guard let (acc, _) = OtpAuthURI.parse(uri) else { XCTFail(); return }
        XCTAssertEqual(acc.issuer, "Acme")
        XCTAssertEqual(acc.name, "bob")
        XCTAssertEqual(acc.algorithm, .sha512)
        XCTAssertEqual(acc.digits, 8)
        XCTAssertEqual(acc.period, 60)
    }

    func test_otpauth_hotp_counter() {
        let uri = "otpauth://hotp/Site:alice?secret=ORSXG5A&counter=42"
        guard let (acc, _) = OtpAuthURI.parse(uri) else { XCTFail(); return }
        XCTAssertEqual(acc.type, .hotp)
        XCTAssertEqual(acc.counter, 42)
    }

    func test_otpauth_invalid() {
        XCTAssertNil(OtpAuthURI.parse("https://example.com"))
        XCTAssertNil(OtpAuthURI.parse("otpauth://totp/foo"))  // no secret
    }

    func test_migration_roundtrip() {
        let originals: [(Account, Data)] = [
            (Account(issuer: "Google", name: "alice@example.com", algorithm: .sha1, digits: 6, period: 30, type: .totp), Data([1,2,3,4,5,6,7,8,9,10])),
            (Account(issuer: "GitHub", name: "alice",             algorithm: .sha256, digits: 8, period: 30, type: .totp), Data([11,12,13,14,15,16,17,18,19,20])),
            (Account(issuer: "Site",   name: "bob",               algorithm: .sha1, digits: 6, period: 30, type: .hotp, counter: 99), Data([21,22,23,24,25]))
        ]

        let uris = MigrationURI.encode(accounts: originals, batchId: 12345)
        XCTAssertFalse(uris.isEmpty)

        var decoded: [(Account, Data)] = []
        for uri in uris {
            guard let parsed = MigrationURI.parse(uri) else { XCTFail("parse \(uri)"); continue }
            decoded.append(contentsOf: parsed)
        }

        XCTAssertEqual(decoded.count, originals.count)
        for (i, (a, s)) in decoded.enumerated() {
            XCTAssertEqual(a.issuer, originals[i].0.issuer)
            XCTAssertEqual(a.name, originals[i].0.name)
            XCTAssertEqual(a.algorithm, originals[i].0.algorithm)
            XCTAssertEqual(a.digits, originals[i].0.digits)
            XCTAssertEqual(a.type, originals[i].0.type)
            if a.type == .hotp {
                XCTAssertEqual(a.counter, originals[i].0.counter)
            }
            XCTAssertEqual(s, originals[i].1)
        }
    }

    func test_migration_splits_into_batches_when_large() {
        // Make 30 accounts that should overflow a single 700-byte batch.
        let secret = Data(repeating: 0xab, count: 20)
        let many: [(Account, Data)] = (0..<30).map { i in
            (Account(issuer: "Issuer-\(i)", name: "user-\(i)@example.com"), secret)
        }
        let uris = MigrationURI.encode(accounts: many)
        XCTAssertGreaterThan(uris.count, 1, "expected multi-batch output")

        // All accounts should still round-trip.
        var total = 0
        for uri in uris {
            if let parsed = MigrationURI.parse(uri) { total += parsed.count }
        }
        XCTAssertEqual(total, 30)
    }
}
