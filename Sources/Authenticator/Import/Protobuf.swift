import Foundation

struct ProtoReader {
    let data: Data
    private(set) var index: Int

    init(_ data: Data) {
        self.data = data
        self.index = data.startIndex
    }

    var isAtEnd: Bool { index >= data.endIndex }

    mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < data.endIndex {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    mutating func readLengthDelimited() -> Data? {
        guard let len = readVarint() else { return nil }
        let length = Int(len)
        guard index + length <= data.endIndex else { return nil }
        let slice = data.subdata(in: index..<(index + length))
        index += length
        return slice
    }

    mutating func skip(wireType: Int) -> Bool {
        switch wireType {
        case 0: return readVarint() != nil
        case 1:
            guard index + 8 <= data.endIndex else { return false }
            index += 8
            return true
        case 2:
            return readLengthDelimited() != nil
        case 5:
            guard index + 4 <= data.endIndex else { return false }
            index += 4
            return true
        default:
            return false
        }
    }
}

struct ProtoTag {
    let field: Int
    let wireType: Int

    init?(rawTag: UInt64) {
        let wt = Int(rawTag & 0x7)
        guard wt <= 5 else { return nil }
        self.wireType = wt
        self.field = Int(rawTag >> 3)
    }
}

struct ProtoWriter {
    private(set) var data = Data()

    private mutating func appendVarint(_ value: UInt64) {
        var v = value
        while v >= 0x80 {
            data.append(UInt8((v & 0x7f) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v))
    }

    private mutating func appendTag(field: Int, wireType: Int) {
        appendVarint(UInt64((field << 3) | wireType))
    }

    mutating func writeVarint(field: Int, _ value: UInt64) {
        appendTag(field: field, wireType: 0)
        appendVarint(value)
    }

    mutating func writeBytes(field: Int, _ bytes: Data) {
        appendTag(field: field, wireType: 2)
        appendVarint(UInt64(bytes.count))
        data.append(bytes)
    }

    mutating func writeString(field: Int, _ string: String) {
        writeBytes(field: field, Data(string.utf8))
    }

    mutating func writeMessage(field: Int, _ build: (inout ProtoWriter) -> Void) {
        var inner = ProtoWriter()
        build(&inner)
        writeBytes(field: field, inner.data)
    }
}
