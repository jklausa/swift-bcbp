import Testing
import Parsing
@testable import SwiftBCBP

@Test
func lengthPrefixedParserRoundtripping() throws {
    let parser = HexLengthPrefixedParser {
        Parse {
            Prefix(5).map(.string)
            Prefix(3).map(.string)
        }
    }

    let originalString = "08HELLOABC"
    let parsed = try parser.parse(originalString)
    #expect(parsed.0 == "HELLO")
    #expect(parsed.1 == "ABC")

    var buffer = "" as Substring
    try parser.print(parsed, into: &buffer)
    #expect(buffer == originalString)
}

@Test
func lengthPrefixedParserRoundtrippingWithSpaces() throws {
    let parser = HexLengthPrefixedParser {
        Rest().map(.string)
    }

    let originalString = "13TEST DATA DATA TEST"
    let parsed = try parser.parse(originalString)
    #expect(parsed == "TEST DATA DATA TEST")

    var buffer = "" as Substring
    try parser.print(parsed, into: &buffer)
    #expect(buffer == originalString)
}

@Test
func multiplePrefixedParsers() throws {
    let parser = ParsePrint {
        HexLengthPrefixedParser {
            Rest().map(.string)
        }
        HexLengthPrefixedParser {
            Int.parser()
        }
    }

    let originalString = "07HELLO  0B12345678901"

    let parsed = try parser.parse(originalString)
    #expect(parsed.0 == "HELLO  ")
    #expect(parsed.1 == 12345678901)

    var buffer = "" as Substring
    try parser.print(parsed, into: &buffer)
    #expect(buffer == originalString)
}


@Test
func twoDigitHexParserThrowsOnTooLargeValue() {
    let parser = TwoDigitHexStringToInt()

    var buffer = "" as Substring
    #expect(throws: BCBPError.hexValueTooBig) {
        try parser.print(256, into: &buffer)
    }
}
