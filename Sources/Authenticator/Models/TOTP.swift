import Foundation
import CryptoKit

enum TOTP {
    static func code(secret: Data, account: Account, at date: Date = Date()) -> String {
        let counter: UInt64
        switch account.type {
        case .totp:
            counter = UInt64(date.timeIntervalSince1970) / UInt64(max(1, account.period))
        case .hotp:
            counter = account.counter
        }
        return hotp(secret: secret, counter: counter, digits: account.digits, algorithm: account.algorithm)
    }

    static func secondsRemaining(period: Int, at date: Date = Date()) -> Int {
        let p = max(1, period)
        return p - (Int(date.timeIntervalSince1970) % p)
    }

    private static func hotp(secret: Data, counter: UInt64, digits: Int, algorithm: TOTPAlgorithm) -> String {
        var be = counter.bigEndian
        let counterBytes = withUnsafeBytes(of: &be) { Data($0) }
        let key = SymmetricKey(data: secret)
        let mac: Data
        switch algorithm {
        case .sha1:
            mac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterBytes, using: key))
        case .sha256:
            mac = Data(HMAC<SHA256>.authenticationCode(for: counterBytes, using: key))
        case .sha512:
            mac = Data(HMAC<SHA512>.authenticationCode(for: counterBytes, using: key))
        }

        let bytes = Array(mac)
        let offset = Int(bytes[bytes.count - 1] & 0x0f)
        let truncated =
            (UInt32(bytes[offset] & 0x7f) << 24) |
            (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8)  |
             UInt32(bytes[offset + 3])

        let d = max(1, min(10, digits))
        let modulus = UInt32(pow(10.0, Double(d)))
        let code = truncated % modulus
        return String(format: "%0\(d)d", code)
    }
}
