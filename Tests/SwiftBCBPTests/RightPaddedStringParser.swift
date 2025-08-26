import Parsing
import Testing
@testable import SwiftBCBP

@Test
func rightPaddedStringParserRoundtrippingWithSpaces() throws {
    let input = "HELLO   "
    let parser = RightPaddedStringParser(length: 8)

    let parsed = try parser.parse(input)
    #expect(parsed == "HELLO")

    var buffer = "" as Substring
    try parser.print(parsed, into: &buffer)

    #expect(buffer == input)
}

@Test
func rightPaddedStringParserRoundtrippingWithoutSpaces() throws {
    let input = "ELLOH"
    let parser = RightPaddedStringParser(length: 5)

    let parsed = try parser.parse(input)
    #expect(parsed == "ELLOH")

    var buffer = "" as Substring
    try parser.print(parsed, into: &buffer)

    #expect(buffer == input)
}
