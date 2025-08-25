import Foundation
import Parsing
import Testing
@testable import SwiftBCBP

@Test("Test parsing", arguments: gatherTestCases())
func bCBP5Example(testCase: BoardingPassTestCase) async throws {
    let boardingPass = try? BoardingPassParser.parse(input: testCase.input)

    let comment = if let filename = testCase.filename {
        "Failed parsing: \(testCase.bracketedInput). To see the failing pass, run:\ncat \(filename) | json_pp"
    } else {
        "Failed parsing:\n\(testCase.bracketedInput)"
    }

    if testCase.input.contains(">6") || testCase.input.contains(">7") || testCase.input.contains(">8") {
        if boardingPass?.conditionalData == nil {
            // swiftlint:disable:next no_print_statements
            print("Failed parsing conditional data in:\n\(testCase.bracketedInput)")
        }
        #expect(boardingPass?.conditionalData != nil)
    }

    #expect(boardingPass != nil, Comment(rawValue: comment))
}

@Test
func pNRRoundtripping() throws {
    let pnrString = "ABC123 "

    let pnr = try PNRParser().parse(pnrString)

    #expect(pnr.pnr == "ABC123")

    let printedPNR = try PNRParser().print(pnr)

    #expect(printedPNR == pnrString)
}

@Test
func securityDataRoundtripping() async throws {
    let securityData = "^460MEUCIQCr+eKlAdvd6CbPfW8cQIK9nBLKO4VCPukkiIZ228CCOgIgRbQE76yR14GsbjvP6GKFl7tBhgMna+iMPvJwo+MrPI0="
    // This an actual snippet from my boarding pass, but given this is... I think...? encrypted, should be fine?

    let securityDataParser = SecurityDataParser()
    let parsedData = try securityDataParser.parse(securityData)

    #expect(parsedData.type == "4")
    #expect(parsedData.length == 96)
    #expect(parsedData
        .data == "MEUCIQCr+eKlAdvd6CbPfW8cQIK9nBLKO4VCPukkiIZ228CCOgIgRbQE76yR14GsbjvP6GKFl7tBhgMna+iMPvJwo+MrPI0=")

    let printedData = try securityDataParser.print(parsedData)

    #expect(printedData == securityData)
}

@Test
func optionalMetadataParser() throws {
    // This a snippet from my real BP (from LH), with the eticket and FF numbers redacted.
    // The "Airline private data" section is intact, but I am pretty sure it is not attributable to me
    let input = ">6180WW7215BLH              2A22099999999990 LH LH 999999999999999     Y*30600000K09  LHS    "

    let parser = ConditionalItemsParser()

    let parsedOutput = try parser.parse(input)

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
func cXEdgeCase() throws {
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

@Test
func aFEdgeCase() async throws {
    // Those, again, are snippets from my real boarding pass, with the etix and FF redacted.
    // AF (and by extension KL?) seems to not bother with encoding anything after the selectee indicator,
    // just chopping it off if not present?
    //
    // They also just don't fill a bunch of other fields that I've seen _most_ other airlines fill out, like
    // the passengerDescription/sourceOfCheckIn/sourceOfIssuance/dateOfIssuance fields.
    //
    // If there is a FF, they do seem to encode a couple more fields.
    //
    // They also seem to have a slightly weird way of encoding the bags, where they just... omit the field entirely? if
    // there
    // are no checked bags. Most of other airlines still include the field, just fill them with spaces.
    // Oh well...
    let inputWithFF = ">60B        KL 2505711111111110    AZ 99999999        "
    let inputWithoutFF = ">60B        KL 0E05799999999990"

    let parser = ConditionalItemsParser()

    let parsedWithFF = try parser.parse(inputWithFF)

    #expect(parsedWithFF.passengerDescription == " ")
    #expect(parsedWithFF.sourceOfCheckIn == " ")
    #expect(parsedWithFF.sourceOfIssuance == " ")
    #expect(parsedWithFF.dateOfIssuance == "    ")
    #expect(parsedWithFF.documentType == " ")
    #expect(parsedWithFF.airlineDesignatorOfIssuer == "KL ")
    #expect(parsedWithFF.firstBagNumber == 0)
    #expect(parsedWithFF.secondBagNumber == 0)
    #expect(parsedWithFF.thirdBagNumber == 0)
    #expect(parsedWithFF.airlineNumericCode == "057")
    #expect(parsedWithFF.documentNumber == "1111111111")
    #expect(parsedWithFF.selecteeIndicator == "0")
    #expect(parsedWithFF.internationalDocumentVerification == " ")
    #expect(parsedWithFF.marketingCarrierDesignator == "   ")
    #expect(parsedWithFF.frequentFlyerAirlineDesignator == "AZ ")
    #expect(parsedWithFF.frequentFlyerNumber == "99999999        ")
    #expect(parsedWithFF.idAdIndicator == "")
    #expect(parsedWithFF.freeBaggageAllowance == "")
    #expect(parsedWithFF.fastTrack == "")
    #expect(parsedWithFF.airlinePrivateData == nil)

    let parsedWithoutFF = try parser.parse(inputWithoutFF)

    #expect(parsedWithoutFF.passengerDescription == " ")
    #expect(parsedWithoutFF.sourceOfCheckIn == " ")
    #expect(parsedWithoutFF.sourceOfIssuance == " ")
    #expect(parsedWithoutFF.dateOfIssuance == "    ")
    #expect(parsedWithoutFF.documentType == " ")
    #expect(parsedWithoutFF.airlineDesignatorOfIssuer == "KL ")
    #expect(parsedWithoutFF.firstBagNumber == 0)
    #expect(parsedWithoutFF.secondBagNumber == 0)
    #expect(parsedWithoutFF.thirdBagNumber == 0)
    #expect(parsedWithoutFF.airlineNumericCode == "057")
    #expect(parsedWithoutFF.documentNumber == "9999999999")
    #expect(parsedWithoutFF.selecteeIndicator == "0")
    #expect(parsedWithoutFF.internationalDocumentVerification == "")
    #expect(parsedWithoutFF.marketingCarrierDesignator == "")
    #expect(parsedWithoutFF.frequentFlyerAirlineDesignator == "")
    #expect(parsedWithoutFF.frequentFlyerNumber == "")
    #expect(parsedWithoutFF.idAdIndicator == "")
    #expect(parsedWithoutFF.freeBaggageAllowance == "")
    #expect(parsedWithoutFF.fastTrack == "")
    #expect(parsedWithoutFF.airlinePrivateData == nil)
}
