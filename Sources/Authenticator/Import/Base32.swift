import Foundation

enum Base32 {
    private static let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    static func decode(_ input: String) -> Data? {
        let cleaned = input
            .uppercased()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard !cleaned.isEmpty else { return Data() }

        var bits: UInt32 = 0
        var bitCount: UInt32 = 0
        var out = Data()
        out.reserveCapacity(cleaned.count * 5 / 8)

        for char in cleaned {
            guard let idx = alphabet.firstIndex(of: char) else { return nil }
            bits = (bits << 5) | UInt32(idx)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                out.append(UInt8((bits >> bitCount) & 0xff))
            }
        }
        return out
    }
}
