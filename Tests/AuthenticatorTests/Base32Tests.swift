import XCTest
@testable import Authenticator

final class Base32Tests: XCTestCase {
    func test_known_vectors() {
        // From RFC 4648 §10
        let cases: [(String, String)] = [
            ("",       ""),
            ("MY",     "f"),
            ("MZXQ",   "fo"),
            ("MZXW6",  "foo"),
            ("MZXW6YQ","foob"),
            ("MZXW6YTB","fooba"),
            ("MZXW6YTBOI","foobar")
        ]
        for (encoded, expected) in cases {
            let data = Base32.decode(encoded)
            XCTAssertEqual(data, Data(expected.utf8), "decode \(encoded)")
        }
    }

    func test_lowercase_and_padding_are_tolerated() {
        XCTAssertEqual(Base32.decode("mzxw6==="), Data("foo".utf8))
        XCTAssertEqual(Base32.decode("MZXW6"), Data("foo".utf8))
        XCTAssertEqual(Base32.decode("mz xw-6"), Data("foo".utf8))
    }

    func test_invalid_returns_nil() {
        XCTAssertNil(Base32.decode("not-a-valid-base32-string!"))
    }
}
