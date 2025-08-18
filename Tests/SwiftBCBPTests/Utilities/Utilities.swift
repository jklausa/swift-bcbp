import Testing
import Foundation
import Parsing

struct BoardingPassTestCase: Codable, CustomTestStringConvertible {
    let filename: String?
    let input: String

    init(filename: String?, input: String) {
        self.filename = filename
        self.input = input
    }

    var testDescription: String {
        // Since whitespace is significant in the BCBP,
        // we're adding the brackets to be able to be see where
        // the actual input ends.
        "「\(input)」"
    }
}

func gatherTestCases() -> [BoardingPassTestCase] {
    [
        genericTestCases(),
        edgeCasesTestCases(),
        privateTestCases()
    ].flatMap { $0 }
}

// Generic test cases from the BCBP5 documentation and other sources.
private func genericTestCases() -> [BoardingPassTestCase] {
    // This is a BP from the BCBP5 documentation.
    let docsExample = "M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 226F001A0025 100"

    return [.init(filename: nil, input: docsExample)]
}

// These contain known-non-compliant boarding passes from my collection, with the personal data stripped out.
private func edgeCasesTestCases() -> [BoardingPassTestCase] {
    return []
}

// Extracted using the `extract-test-data.sh` script, run `make extract-test-data` to
private func privateTestCases() -> [BoardingPassTestCase] {
    let resources = Bundle.module.urls(forResourcesWithExtension: ".txt", subdirectory: "Examples")

    guard let resources, !resources.isEmpty else {
        // When Swift 6.3 lands, this should be a `warning`, not a fatal error.
        // But these seem to be silently swallowed anyway, and not reported anywhere anyway, so we can probably get away with it for now..
        Issue.record("No local test cases found in the Examples directory. Run `make extract-test-data` to generate them.")
        return []
    }

    
    var testCases: [BoardingPassTestCase] = []

    for resource in resources {
        guard let input = try? String(contentsOf: resource, encoding: .utf8) else {
            continue
        }

        do {
            let parsedTestCases = try TestCaseParser().parse(input)
            testCases.append(contentsOf: parsedTestCases)
        } catch {
            print(error)
        }
    }

    return testCases
}

fileprivate struct TestCaseParser: Parser {
    var body: some Parser<Substring, [BoardingPassTestCase]> {
        Parse(input: Substring.self) {
            $0.map { BoardingPassTestCase(filename: $0, input: $1) }
        }
        with: {
            Many(1...) {
                PrefixThrough("pass.json").map(String.init)
                ": "
                PrefixUpTo("\n").map(String.init)
                "\n"
            }
        }
    }
}
