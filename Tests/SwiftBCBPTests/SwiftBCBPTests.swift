import Testing
import Foundation
import Parsing
@testable import SwiftBCBP


@Test("Test parsing", arguments: gatherTestCases())
func testBCBP5Example(testCase: BoardingPassTestCase) async throws {
    let boardingPass = try BoardingPassParser.parse(input: testCase.input)

    if boardingPass == nil, let path = testCase.filename {
        Issue.record("Failure on BP with path: \(path)")
    }


    #expect(boardingPass != nil)
}
