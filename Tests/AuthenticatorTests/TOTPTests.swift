import XCTest
@testable import Authenticator

final class TOTPTests: XCTestCase {
    // RFC 6238 Appendix B test vectors.
    // The published vectors are for 8-digit codes. 6-digit codes are the last 6 chars.

    func test_sha1_rfc6238_vectors() {
        let secret = Data("12345678901234567890".utf8)
        let acc = Account(issuer: "RFC", name: "sha1", algorithm: .sha1, digits: 8, period: 30, type: .totp)
        let cases: [(time: TimeInterval, expected: String)] = [
            (59,           "94287082"),
            (1_111_111_109,"07081804"),
            (1_111_111_111,"14050471"),
            (1_234_567_890,"89005924"),
            (2_000_000_000,"69279037"),
            (20_000_000_000,"65353130")
        ]
        for c in cases {
            let code = TOTP.code(secret: secret, account: acc, at: Date(timeIntervalSince1970: c.time))
            XCTAssertEqual(code, c.expected, "SHA1 t=\(c.time)")
        }
    }

    func test_sha256_rfc6238_vectors() {
        let secret = Data("12345678901234567890123456789012".utf8)
        let acc = Account(issuer: "RFC", name: "sha256", algorithm: .sha256, digits: 8, period: 30, type: .totp)
        let cases: [(time: TimeInterval, expected: String)] = [
            (59,           "46119246"),
            (1_111_111_109,"68084774"),
            (1_111_111_111,"67062674"),
            (1_234_567_890,"91819424"),
            (2_000_000_000,"90698825"),
            (20_000_000_000,"77737706")
        ]
        for c in cases {
            let code = TOTP.code(secret: secret, account: acc, at: Date(timeIntervalSince1970: c.time))
            XCTAssertEqual(code, c.expected, "SHA256 t=\(c.time)")
        }
    }

    func test_sha512_rfc6238_vectors() {
        let secret = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)
        let acc = Account(issuer: "RFC", name: "sha512", algorithm: .sha512, digits: 8, period: 30, type: .totp)
        let cases: [(time: TimeInterval, expected: String)] = [
            (59,           "90693936"),
            (1_111_111_109,"25091201"),
            (1_111_111_111,"99943326"),
            (1_234_567_890,"93441116"),
            (2_000_000_000,"38618901"),
            (20_000_000_000,"47863826")
        ]
        for c in cases {
            let code = TOTP.code(secret: secret, account: acc, at: Date(timeIntervalSince1970: c.time))
            XCTAssertEqual(code, c.expected, "SHA512 t=\(c.time)")
        }
    }

    func test_6digit_is_last_6_of_8digit() {
        let secret = Data("12345678901234567890".utf8)
        let acc6 = Account(issuer: "", name: "", algorithm: .sha1, digits: 6, period: 30, type: .totp)
        let code = TOTP.code(secret: secret, account: acc6, at: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code, "287082")
    }

    func test_hotp_uses_counter_not_time() {
        let secret = Data("12345678901234567890".utf8)
        var acc = Account(issuer: "", name: "", algorithm: .sha1, digits: 6, period: 30, type: .hotp, counter: 0)
        // RFC 4226 test vectors for HOTP/SHA1.
        let expected = ["755224", "287082", "359152", "969429", "338314"]
        for i in 0..<expected.count {
            acc.counter = UInt64(i)
            let code = TOTP.code(secret: secret, account: acc, at: Date(timeIntervalSince1970: 9_999_999_999))
            XCTAssertEqual(code, expected[i], "HOTP counter=\(i)")
        }
    }

    func test_secondsRemaining() {
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, at: Date(timeIntervalSince1970: 0)),  30)
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, at: Date(timeIntervalSince1970: 1)),  29)
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, at: Date(timeIntervalSince1970: 30)), 30)
        XCTAssertEqual(TOTP.secondsRemaining(period: 30, at: Date(timeIntervalSince1970: 59)),  1)
    }
}
