import Foundation

/// Decodes Google Authenticator's `otpauth-migration://offline?data=...` export URIs.
///
/// The `data` parameter is URL-encoded, base64-encoded protobuf with this schema:
///
///   message MigrationPayload {
///     repeated OtpParameters otp_parameters = 1;
///     int32 version       = 2;
///     int32 batch_size    = 3;
///     int32 batch_index   = 4;
///     int32 batch_id      = 5;
///   }
///   message OtpParameters {
///     bytes  secret    = 1;
///     string name      = 2;
///     string issuer    = 3;
///     int32  algorithm = 4;  // 1=SHA1, 2=SHA256, 3=SHA512, 4=MD5
///     int32  digits    = 5;  // 1=six, 2=eight
///     int32  type      = 6;  // 1=hotp, 2=totp
///     int64  counter   = 7;
///   }
enum MigrationURI {
    static func parse(_ uri: String) -> [(Account, Data)]? {
        guard let comps = URLComponents(string: uri),
              comps.scheme?.lowercased() == "otpauth-migration",
              comps.host?.lowercased() == "offline",
              let encoded = comps.queryItems?.first(where: { $0.name == "data" })?.value
        else { return nil }

        // The base64 may contain `+/=` which are typically URL-encoded.
        // URLComponents already decoded percent-escapes for us.
        let normalized = encoded
            .replacingOccurrences(of: " ", with: "+")
        guard let payload = Data(base64Encoded: normalized) else { return nil }

        return decodePayload(payload)
    }

    private static func decodePayload(_ data: Data) -> [(Account, Data)]? {
        var reader = ProtoReader(data)
        var out: [(Account, Data)] = []

        while !reader.isAtEnd {
            guard let rawTag = reader.readVarint(), let tag = ProtoTag(rawTag: rawTag) else {
                return nil
            }
            if tag.field == 1 && tag.wireType == 2 {
                guard let nested = reader.readLengthDelimited() else { return nil }
                if let parsed = decodeOtpParameters(nested) {
                    out.append(parsed)
                }
            } else {
                if !reader.skip(wireType: tag.wireType) { return nil }
            }
        }
        return out
    }

    private static func decodeOtpParameters(_ data: Data) -> (Account, Data)? {
        var reader = ProtoReader(data)
        var secret = Data()
        var name = ""
        var issuer = ""
        var algoRaw: Int = 1
        var digitsRaw: Int = 1
        var typeRaw: Int = 2
        var counter: UInt64 = 0

        while !reader.isAtEnd {
            guard let rawTag = reader.readVarint(), let tag = ProtoTag(rawTag: rawTag) else {
                return nil
            }
            switch (tag.field, tag.wireType) {
            case (1, 2):
                guard let bytes = reader.readLengthDelimited() else { return nil }
                secret = bytes
            case (2, 2):
                guard let bytes = reader.readLengthDelimited() else { return nil }
                name = String(data: bytes, encoding: .utf8) ?? ""
            case (3, 2):
                guard let bytes = reader.readLengthDelimited() else { return nil }
                issuer = String(data: bytes, encoding: .utf8) ?? ""
            case (4, 0):
                guard let v = reader.readVarint() else { return nil }
                algoRaw = Int(v)
            case (5, 0):
                guard let v = reader.readVarint() else { return nil }
                digitsRaw = Int(v)
            case (6, 0):
                guard let v = reader.readVarint() else { return nil }
                typeRaw = Int(v)
            case (7, 0):
                guard let v = reader.readVarint() else { return nil }
                counter = v
            default:
                if !reader.skip(wireType: tag.wireType) { return nil }
            }
        }

        guard !secret.isEmpty else { return nil }

        let algorithm: TOTPAlgorithm
        switch algoRaw {
        case 2: algorithm = .sha256
        case 3: algorithm = .sha512
        default: algorithm = .sha1   // 0=unspecified, 1=SHA1, 4=MD5 (unsupported -> SHA1)
        }

        let digits: Int = (digitsRaw == 2) ? 8 : 6
        let type: OTPType = (typeRaw == 1) ? .hotp : .totp

        let account = Account(
            issuer: issuer,
            name: name,
            algorithm: algorithm,
            digits: digits,
            period: 30,
            type: type,
            counter: counter
        )
        return (account, secret)
    }

    // MARK: - Encoding

    /// Build `otpauth-migration://offline?data=...` URIs from a list of
    /// (Account, secret) pairs. Splits into multiple URIs if the encoded
    /// payload would exceed `maxBytesPerBatch`, matching Google's behavior
    /// when many accounts are exported.
    static func encode(
        accounts: [(Account, Data)],
        maxBytesPerBatch: Int = 700,
        batchId: Int32 = Int32.random(in: 1...Int32.max)
    ) -> [String] {
        let perAccount = accounts.map { encodeAccount($0.0, secret: $0.1) }

        // Greedy bin-packing.
        var batches: [[Data]] = [[]]
        var currentSize = 0
        for blob in perAccount {
            if currentSize + blob.count > maxBytesPerBatch && !batches[batches.count - 1].isEmpty {
                batches.append([])
                currentSize = 0
            }
            batches[batches.count - 1].append(blob)
            currentSize += blob.count
        }

        return batches.enumerated().map { (idx, blobs) in
            var w = ProtoWriter()
            for blob in blobs {
                w.writeBytes(field: 1, blob)  // otp_parameters
            }
            w.writeVarint(field: 2, 1)                              // version
            w.writeVarint(field: 3, UInt64(batches.count))          // batch_size
            w.writeVarint(field: 4, UInt64(idx))                    // batch_index
            w.writeVarint(field: 5, UInt64(UInt32(bitPattern: batchId))) // batch_id

            let base64 = w.data.base64EncodedString()
            var comps = URLComponents()
            comps.scheme = "otpauth-migration"
            comps.host = "offline"
            comps.queryItems = [URLQueryItem(name: "data", value: base64)]
            return comps.url?.absoluteString ?? "otpauth-migration://offline?data=\(base64)"
        }
    }

    private static func encodeAccount(_ acc: Account, secret: Data) -> Data {
        var w = ProtoWriter()
        w.writeBytes(field: 1, secret)
        w.writeString(field: 2, acc.name)
        w.writeString(field: 3, acc.issuer)

        let algo: UInt64
        switch acc.algorithm {
        case .sha1: algo = 1
        case .sha256: algo = 2
        case .sha512: algo = 3
        }
        w.writeVarint(field: 4, algo)
        w.writeVarint(field: 5, acc.digits == 8 ? 2 : 1)
        w.writeVarint(field: 6, acc.type == .hotp ? 1 : 2)
        if acc.type == .hotp {
            w.writeVarint(field: 7, acc.counter)
        }
        return w.data
    }
}
