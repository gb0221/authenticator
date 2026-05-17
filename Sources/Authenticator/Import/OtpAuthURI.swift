import Foundation

enum OtpAuthURI {
    /// Parses an `otpauth://totp/...` or `otpauth://hotp/...` URI.
    /// Returns the Account plus the raw secret bytes (base32-decoded).
    static func parse(_ uri: String) -> (Account, Data)? {
        guard let comps = URLComponents(string: uri),
              comps.scheme?.lowercased() == "otpauth",
              let host = comps.host?.lowercased()
        else { return nil }

        let type: OTPType
        switch host {
        case "totp": type = .totp
        case "hotp": type = .hotp
        default: return nil
        }

        // Path is `/Issuer:Account` or `/Account`, percent-encoded.
        let rawLabel = String(comps.path.drop(while: { $0 == "/" }))
        let label = rawLabel.removingPercentEncoding ?? rawLabel
        var issuer = ""
        var name = label
        if let colon = label.firstIndex(of: ":") {
            issuer = String(label[..<colon]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }

        var secret: Data?
        var algorithm: TOTPAlgorithm = .sha1
        var digits = 6
        var period = 30
        var counter: UInt64 = 0

        for item in comps.queryItems ?? [] {
            let value = item.value ?? ""
            switch item.name.lowercased() {
            case "secret":
                secret = Base32.decode(value)
            case "issuer":
                if issuer.isEmpty { issuer = value }
            case "algorithm":
                algorithm = TOTPAlgorithm(rawValue: value.uppercased()) ?? .sha1
            case "digits":
                digits = Int(value) ?? 6
            case "period":
                period = Int(value) ?? 30
            case "counter":
                counter = UInt64(value) ?? 0
            default:
                break
            }
        }

        guard let secretData = secret, !secretData.isEmpty else { return nil }

        let account = Account(
            issuer: issuer,
            name: name,
            algorithm: algorithm,
            digits: digits,
            period: period,
            type: type,
            counter: counter
        )
        return (account, secretData)
    }
}
