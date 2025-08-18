import Testing
import Foundation
import Parsing
@testable import SwiftBCBP


@Test("Test parsing", arguments: gatherTestCases())
func testBCBP5Example(testCase: BoardingPassTestCase) async throws {
    let boardingPass = try? BoardingPassParser.parse(input: testCase.input)

    let comment = if let filename = testCase.filename {
        "Failed parsing: \(testCase.testDescription). To see the failing pass, run:\ncat \(filename) | json_pp"
    } else {
        "Failed parsing:\n\(testCase.testDescription)"
    }

    #expect(boardingPass != nil, Comment(rawValue: comment))
}
