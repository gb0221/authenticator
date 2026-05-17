import Foundation

enum TOTPAlgorithm: String, Codable, CaseIterable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
}

enum OTPType: String, Codable {
    case totp
    case hotp
}

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var issuer: String
    var name: String
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int
    var type: OTPType
    var counter: UInt64

    init(
        id: UUID = UUID(),
        issuer: String,
        name: String,
        algorithm: TOTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        type: OTPType = .totp,
        counter: UInt64 = 0
    ) {
        self.id = id
        self.issuer = issuer
        self.name = name
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.type = type
        self.counter = counter
    }

    var displayTitle: String {
        if issuer.isEmpty { return name }
        if name.isEmpty { return issuer }
        return "\(issuer) — \(name)"
    }
}
