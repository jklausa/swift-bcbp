import Testing
import Foundation
import Parsing
@testable import SwiftBCBP

struct BoardingPassTestCase {
    let filename: String?
    let input: String

    init(filename: String?, input: String) {
        self.filename = filename
        self.input = input
    }

}

private func gatherTestCases() -> [BoardingPassTestCase] {
    let docsExample = "M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 226F001A0025 100"
    // This is a BP from the BCBP5 documentation.

    let resources = Bundle.module.urls(forResourcesWithExtension: ".txt", subdirectory: "Examples")
    guard let resources, !resources.isEmpty else {
        return [.init(filename: nil, input: docsExample)]
    }

    var testCases: [BoardingPassTestCase] = [.init(filename: nil, input: docsExample)]

    let testCaseParser = Parse(input: Substring.self) {
        $0.map { BoardingPassTestCase(filename: $0, input: $1) }
    }
    with: {
        Many(1...){
            PrefixThrough("pass.json").map(String.init)
            ": "
            PrefixThrough("\n").map(String.init)
        }
    }

    for resource in resources {
        guard let input = try? String(contentsOf: resource, encoding: .utf8) else {
            continue
        }

        do {
            let parsedTestCases = try testCaseParser.parse(input)
            testCases.append(contentsOf: parsedTestCases)
        } catch {
            print(error)
        }
    }

    return testCases
}

@Test("Test parsing", arguments: gatherTestCases())
func testBCBP5Example(testCase: BoardingPassTestCase) async throws {
    let boardingPass = try BoardingPassParser.parse(input: testCase.input)

    #expect(boardingPass != nil)
}
