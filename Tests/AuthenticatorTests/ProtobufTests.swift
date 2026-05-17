import XCTest
@testable import Authenticator

final class ProtobufTests: XCTestCase {
    func test_writer_reader_varint_roundtrip() {
        var w = ProtoWriter()
        w.writeVarint(field: 1, 0)
        w.writeVarint(field: 2, 150)
        w.writeVarint(field: 3, .max)

        var r = ProtoReader(w.data)
        var fields: [(field: Int, value: UInt64)] = []
        while !r.isAtEnd {
            guard let raw = r.readVarint(), let tag = ProtoTag(rawTag: raw) else { return }
            guard let v = r.readVarint() else { return }
            fields.append((tag.field, v))
        }
        XCTAssertEqual(fields.map { $0.field }, [1, 2, 3])
        XCTAssertEqual(fields.map { $0.value }, [0, 150, .max])
    }

    func test_writer_reader_length_delimited() {
        let payload = Data([0xde, 0xad, 0xbe, 0xef])
        var w = ProtoWriter()
        w.writeBytes(field: 4, payload)
        w.writeString(field: 5, "hello")

        var r = ProtoReader(w.data)
        guard let raw1 = r.readVarint(), let tag1 = ProtoTag(rawTag: raw1),
              let bytes = r.readLengthDelimited() else {
            XCTFail("read failed"); return
        }
        XCTAssertEqual(tag1.field, 4)
        XCTAssertEqual(bytes, payload)

        guard let raw2 = r.readVarint(), let tag2 = ProtoTag(rawTag: raw2),
              let str = r.readLengthDelimited() else {
            XCTFail("read failed"); return
        }
        XCTAssertEqual(tag2.field, 5)
        XCTAssertEqual(String(data: str, encoding: .utf8), "hello")
    }

    func test_skip_varint_field() {
        var w = ProtoWriter()
        w.writeVarint(field: 1, 99)
        w.writeVarint(field: 2, 7)
        var r = ProtoReader(w.data)

        guard let raw = r.readVarint(), let tag = ProtoTag(rawTag: raw) else {
            XCTFail("read failed"); return
        }
        XCTAssertEqual(tag.wireType, 0)
        XCTAssertTrue(r.skip(wireType: 0))

        guard let raw2 = r.readVarint(), let tag2 = ProtoTag(rawTag: raw2),
              let v = r.readVarint() else {
            XCTFail("read failed"); return
        }
        XCTAssertEqual(tag2.field, 2)
        XCTAssertEqual(v, 7)
    }
}
