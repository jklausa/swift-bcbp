import Testing
import Foundation
import Parsing
@testable import SwiftBCBP


@Test("Test parsing", arguments: gatherTestCases())
func testBCBP5Example(testCase: BoardingPassTestCase) async throws {
    let boardingPass = try? BoardingPassParser.parse(input: testCase.input)

    let comment = if let filename = testCase.filename {
        "Failed parsing: \(testCase.bracketedInput). To see the failing pass, run:\ncat \(filename) | json_pp"
    } else {
        "Failed parsing:\n\(testCase.bracketedInput)"
    }

    if testCase.input.contains(">6") || testCase.input.contains(">7") || testCase.input.contains(">8") {
        if boardingPass?.conditionalData == nil {
            print("Failed parsing conditional data in:\n\(testCase.bracketedInput)")
        }
        #expect(boardingPass?.conditionalData != nil)
    }

    #expect(boardingPass != nil, Comment(rawValue: comment))
}

@Test
func testPNRRoundtripping() throws {
    let pnrString = "ABC123 "

    let pnr = try PNRParser().parse(pnrString)

    #expect(pnr.pnr == "ABC123")

    let printedPNR = try PNRParser().print(pnr)

    #expect(printedPNR == pnrString)
}

@Test
func testSecurityDataRoundtripping() async throws {
    let securityData = "^460MEUCIQCr+eKlAdvd6CbPfW8cQIK9nBLKO4VCPukkiIZ228CCOgIgRbQE76yR14GsbjvP6GKFl7tBhgMna+iMPvJwo+MrPI0="
    // This an actual snippet from my boarding pass, but given this is... I think...? encrypted, should be fine?

    let securityDataParser = SecurityDataParser()
    let parsedData = try securityDataParser.parse(securityData)

    #expect(parsedData.type == "4")
    #expect(parsedData.length == 96)
    #expect(parsedData.data == "MEUCIQCr+eKlAdvd6CbPfW8cQIK9nBLKO4VCPukkiIZ228CCOgIgRbQE76yR14GsbjvP6GKFl7tBhgMna+iMPvJwo+MrPI0=")

    let printedData = try securityDataParser.print(parsedData)

    #expect(printedData == securityData)
}

@Test
func testOptionalMetadataParser() throws {
    // This a snippet from my real BP (from LH), with the eticket and FF numbers redacted.
    // The "Airline private data" section is intact, but I am pretty sure it is not attributable to me
    let input = ">6180WW7215BLH              2A22099999999990 LH LH 999999999999999     Y*30600000K09  LHS    "

    let parser = ConditionalItemsParser()

    let parsedOutput = try parser.parse(input)

    print(parsedOutput)

    #expect(parsedOutput.passengerDescription == "0")
    #expect(parsedOutput.sourceOfCheckIn == "W")
    #expect(parsedOutput.sourceOfIssuance == "W")
    #expect(parsedOutput.dateOfIssuance == "7215")
    #expect(parsedOutput.documentType == "B")
    #expect(parsedOutput.airlineDesignatorOfIssuer == "LH ")

    #expect(parsedOutput.airlineNumericCode == "220")
    #expect(parsedOutput.documentNumber == "9999999999")

    #expect(parsedOutput.selecteeIndicator == "0")
    #expect(parsedOutput.internationalDocumentVerification == " ")

    #expect(parsedOutput.marketingCarrierDesignator == "LH ")

    #expect(parsedOutput.frequentFlyerAirlineDesignator == "LH ")
    #expect(parsedOutput.frequentFlyerNumber == "999999999999999 ")
    #expect(parsedOutput.fastTrack == "Y")
    #expect(parsedOutput.airlinePrivateData == "*30600000K09  LHS    ")
}

@Test
func testCXEdgeCase() throws {
    // This is again a snippet from my real boarding pass, with the etix and FF redacted.
    // CX seemed to have an unusual way of encoding the bag numbers, which I have not seen in other passes,
    // where they fill out all three bag numbers with empty space when there are no bags.
    let input = ">6320WW9295BCX                                        2A1259999999999 1CX BA 99999999         20KN1BA"

    let parser = ConditionalItemsParser()

    let parsedOutput = try parser.parse(input)

    #expect(parsedOutput.passengerDescription == "0")
    #expect(parsedOutput.sourceOfCheckIn == "W")
    #expect(parsedOutput.sourceOfIssuance == "W")
    #expect(parsedOutput.dateOfIssuance == "9295")
    #expect(parsedOutput.documentType == "B")
    #expect(parsedOutput.airlineDesignatorOfIssuer == "CX ")
    #expect(parsedOutput.firstBagNumber == 0)
    #expect(parsedOutput.secondBagNumber == 0)
    #expect(parsedOutput.thirdBagNumber == 0)
    #expect(parsedOutput.airlineNumericCode == "125")
    #expect(parsedOutput.documentNumber == "9999999999")
    #expect(parsedOutput.selecteeIndicator == " ")
    #expect(parsedOutput.internationalDocumentVerification == "1")
    #expect(parsedOutput.marketingCarrierDesignator == "CX ")
    #expect(parsedOutput.frequentFlyerAirlineDesignator == "BA ")
    #expect(parsedOutput.frequentFlyerNumber == "99999999        ")
    #expect(parsedOutput.idAdIndicator == " ")
    #expect(parsedOutput.freeBaggageAllowance == "20K")
    #expect(parsedOutput.fastTrack == "N")
    #expect(parsedOutput.airlinePrivateData == "1BA")
}

