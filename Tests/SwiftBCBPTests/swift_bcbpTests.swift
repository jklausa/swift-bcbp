import Testing
@testable import SwiftBCBP

@Test

func example() async throws {
    let example = "M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 226F001A0025 100"
    let boardingPass = try BoardingPassParser.parse(input: example)

    #expect(boardingPass != nil)

}
