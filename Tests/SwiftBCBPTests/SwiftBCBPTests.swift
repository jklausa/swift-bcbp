import Foundation
import Parsing
import Testing
@testable import SwiftBCBP

@Test("Test parsing", arguments: gatherTestCases())
func parseAndValidateFields(testCase: BoardingPassTestCase) async throws {
    do {
        let boardingPass = try RawBoardingPassParser().parse(testCase.input)

        withKnownIssue {
            if testCase.input.contains(">") {
                #expect(boardingPass.conditionalData != nil, "Failed parsing conditional data in:\n\(testCase.bracketedInput)")
            }
        } when: {
            // This BP seems to have a completely malformed conditional data section.
            // I will add it to the known issues for now, and add a test to illustrate the issue.
            testCase.filename?
                .hasSuffix("lK5p0BOtTw66-oDpYyI6pmwB920=.pkpass/pass.json") == true
        }

        if testCase.input.contains("^") {
            #expect(boardingPass.securityData != nil, "Failed parsing security data in:\n\(testCase.bracketedInput)")
        }
    } catch {
        let comment = if let filename = testCase.filename {
            "Failed parsing: \(testCase.bracketedInput). To see the failing pass, run:\ncat \(filename) | json_pp"
        } else {
            "Failed parsing:\n\(testCase.bracketedInput)"
        }

        Issue.record(error, Comment(rawValue: comment))
    }
}

@Test
func securityDataRoundtripping() async throws {
    let securityData = "^460MEUCIQCr+eKlAdvd6CbPfW8cQIK9nBLKO4VCPukkiIZ228CCOgIgRbQE76yR14GsbjvP6GKFl7tBhgMna+iMPvJwo+MrPI0="
    // This an actual snippet from my boarding pass, but given this is... I think...? encrypted, should be fine?

    let securityDataParser = SecurityDataParser()
    let parsedData = try securityDataParser.parse(securityData)

    #expect(parsedData.type == "4")
    #expect(parsedData.data.count == 96)
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

    let parser = FirstSegmentConditionalItemsParser()
    let parsedOutput = try parser.parse(input)

    #expect(parsedOutput.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsedOutput.conditionalUniqueItems.sourceOfCheckIn == "W")
    #expect(parsedOutput.conditionalUniqueItems.sourceOfIssuance == "W")
    #expect(parsedOutput.conditionalUniqueItems.dateOfIssuance == "7215")
    #expect(parsedOutput.conditionalUniqueItems.documentType == "B")
    #expect(parsedOutput.conditionalUniqueItems.airlineDesignatorOfIssuer == "LH")
    #expect(parsedOutput.conditionalUniqueItems.bags == [.emptyString])

    #expect(parsedOutput.conditionalRepeatingItems.airlineNumericCode == "220")
    #expect(parsedOutput.conditionalRepeatingItems.documentNumber == "9999999999")
    #expect(parsedOutput.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(parsedOutput.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems.marketingCarrierDesignator == "LH")
    #expect(parsedOutput.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "LH")
    #expect(parsedOutput.conditionalRepeatingItems.frequentFlyerNumber == "999999999999999")
    #expect(parsedOutput.conditionalRepeatingItems.fastTrack == "Y")
    #expect(parsedOutput.conditionalRepeatingItems.airlinePrivateData == "*30600000K09  LHS    ")

    let printedData = try parser.print(parsedOutput)
    #expect(printedData == input)
}

@Test
func cathayEdgeCase() throws {
    // This is again a snippet from my real boarding pass, with the etix and FF redacted.
    // CX seemed to have an unusual way of encoding the bag numbers, which I have not seen in other passes,
    // where they fill out all three bag numbers with empty space when there are no bags.
    let input = ">6320WW9295BCX                                        2A1259999999999 1CX BA 99999999         20KN1BA"

    let parser = FirstSegmentConditionalItemsParser()

    let parsedOutput = try parser.parse(input)

    #expect(parsedOutput.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsedOutput.conditionalUniqueItems.sourceOfCheckIn == "W")
    #expect(parsedOutput.conditionalUniqueItems.sourceOfIssuance == "W")
    #expect(parsedOutput.conditionalUniqueItems.dateOfIssuance == "9295")
    #expect(parsedOutput.conditionalUniqueItems.documentType == "B")
    #expect(parsedOutput.conditionalUniqueItems.airlineDesignatorOfIssuer == "CX")
    #expect(parsedOutput.conditionalUniqueItems.bags == [.emptyString, .emptyString, .emptyString])

    #expect(parsedOutput.conditionalRepeatingItems.airlineNumericCode == "125")
    #expect(parsedOutput.conditionalRepeatingItems.documentNumber == "9999999999")
    #expect(parsedOutput.conditionalRepeatingItems.selecteeIndicator?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems.internationalDocumentVerification == "1")
    #expect(parsedOutput.conditionalRepeatingItems.marketingCarrierDesignator == "CX")
    #expect(parsedOutput.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "BA")
    #expect(parsedOutput.conditionalRepeatingItems.frequentFlyerNumber == "99999999")
    #expect(parsedOutput.conditionalRepeatingItems.idAdIndicator?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems.freeBaggageAllowance == "20K")
    #expect(parsedOutput.conditionalRepeatingItems.fastTrack == "N")
    #expect(parsedOutput.conditionalRepeatingItems.airlinePrivateData == "1BA")

    let printedData = try parser.print(parsedOutput)
    #expect(printedData == input)
}

@Test
func airFranceEdgeCase() async throws {
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

    let parser = FirstSegmentConditionalItemsParser()

    let parsedWithFF = try parser.parse(inputWithFF)

    #expect(parsedWithFF.conditionalUniqueItems.passengerDescription.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.dateOfIssuance?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.documentType?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.airlineDesignatorOfIssuer == "KL")
    #expect(parsedWithFF.conditionalUniqueItems.bags == nil)

    #expect(parsedWithFF.conditionalRepeatingItems.airlineNumericCode == "057")
    #expect(parsedWithFF.conditionalRepeatingItems.documentNumber == "1111111111")
    #expect(parsedWithFF.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(
        parsedWithFF.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty == true,
    )
    #expect(parsedWithFF.conditionalRepeatingItems.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsedWithFF.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "AZ")
    #expect(parsedWithFF.conditionalRepeatingItems.frequentFlyerNumber == "99999999")

    // Note the difference here between `== nil` and `?.isEmpty == true` previously.
    // `nil` means the field was not encoded at all, whereas `?.isEmpty == true` means
    // the field was encoded, but empty.
    #expect(parsedWithFF.conditionalRepeatingItems.idAdIndicator == nil)
    #expect(parsedWithFF.conditionalRepeatingItems.freeBaggageAllowance?.isEmpty == nil)
    #expect(parsedWithFF.conditionalRepeatingItems.fastTrack == nil)
    #expect(parsedWithFF.conditionalRepeatingItems.airlinePrivateData == nil)

    let printedWithFF = try parser.print(parsedWithFF)
    #expect(printedWithFF == inputWithFF)

    let parsedWithoutFF = try parser.parse(inputWithoutFF)

    #expect(parsedWithoutFF.conditionalUniqueItems.passengerDescription.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.dateOfIssuance?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.documentType?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.airlineDesignatorOfIssuer == "KL")
    #expect(parsedWithoutFF.conditionalUniqueItems.bags == nil)

    #expect(parsedWithoutFF.conditionalRepeatingItems.airlineNumericCode == "057")
    #expect(parsedWithoutFF.conditionalRepeatingItems.documentNumber == "9999999999")
    #expect(parsedWithoutFF.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(parsedWithoutFF.conditionalRepeatingItems.internationalDocumentVerification == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.marketingCarrierDesignator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.frequentFlyerAirlineDesignator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.frequentFlyerNumber == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.idAdIndicator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.freeBaggageAllowance == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.fastTrack == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems.airlinePrivateData == nil)

    let printedWithoutFF = try parser.print(parsedWithoutFF)
    #expect(printedWithoutFF == inputWithoutFF)
}

@Test
func oldAirFranceEdgeCase() throws {
    // This is an older AF pass, which similarly to the previous one, omits a bunch of data in the "mandatory"
    // section, but even more radically than the other one.

    let input = ">503  M2A07466666666660    AZ 0002222222          Y"
    let parser = FirstSegmentConditionalItemsParser()
    let parsed = try parser.parse(input)

    #expect(parsed.conditionalUniqueItems.passengerDescription.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.sourceOfIssuance == "M")

    // Again, note the difference between `== nil` and `?.isEmpty == true` here.

    #expect(parsed.conditionalUniqueItems.dateOfIssuance == nil)
    #expect(parsed.conditionalUniqueItems.documentType == nil)
    #expect(parsed.conditionalUniqueItems.airlineDesignatorOfIssuer == nil)
    #expect(parsed.conditionalUniqueItems.bags == nil)

    #expect(parsed.conditionalRepeatingItems.airlineNumericCode == "074")
    #expect(parsed.conditionalRepeatingItems.documentNumber == "6666666666")
    #expect(parsed.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "AZ")
    #expect(parsed.conditionalRepeatingItems.frequentFlyerNumber == "0002222222")
    #expect(parsed.conditionalRepeatingItems.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.fastTrack == "Y")
    #expect(parsed.conditionalRepeatingItems.airlinePrivateData == nil)

    let printedData = try parser.print(parsed)
    #expect(printedData == input)
}

@Test
func airBerlinEdgeCase() throws {
    // I got some AB (RIP!) passes that seem to omit some of the fields from the "mandatory" data.
    // I am... not sure how spec-compliant that is, but hey, it's real data.
    let input = ">5080      B2A             0    AB 777777777           Y11G"
    let parser = FirstSegmentConditionalItemsParser()
    let parsed = try parser.parse(input)

    #expect(parsed.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsed.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.dateOfIssuance?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalUniqueItems.airlineDesignatorOfIssuer == nil)
    #expect(parsed.conditionalUniqueItems.bags == nil)

    #expect(parsed.conditionalRepeatingItems.airlineNumericCode?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.documentNumber?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "AB")
    #expect(parsed.conditionalRepeatingItems.frequentFlyerNumber == "777777777")
    #expect(parsed.conditionalRepeatingItems.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems.fastTrack == "Y")
    #expect(parsed.conditionalRepeatingItems.airlinePrivateData == "11G")

    let printedData = try parser.print(parsed)
    #expect(printedData == input)
}

@Test
func scandinavianEdgeCase() throws {
    // SK chops off optional fields after the FF, with no ID/AD / luggage-allowance or fast-track.
    let input = ">50B1WM7308BSK 2511733333333330 SK TK 555555555       N*3000500TKG1"
    let parser = FirstSegmentConditionalItemsParser()
    let parsed = try parser.parse(input)

    #expect(parsed.conditionalUniqueItems.passengerDescription == "1")
    #expect(parsed.conditionalUniqueItems.sourceOfCheckIn == "W")
    #expect(parsed.conditionalUniqueItems.sourceOfIssuance == "M")
    #expect(parsed.conditionalUniqueItems.dateOfIssuance == "7308")
    #expect(parsed.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalUniqueItems.airlineDesignatorOfIssuer == "SK")
    #expect(parsed.conditionalUniqueItems.bags == nil)

    #expect(parsed.conditionalRepeatingItems.airlineNumericCode == "117")
    #expect(parsed.conditionalRepeatingItems.documentNumber == "3333333333")
    #expect(parsed.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems.marketingCarrierDesignator == "SK")
    #expect(parsed.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "TK")
    #expect(parsed.conditionalRepeatingItems.frequentFlyerNumber == "555555555")

    #expect(parsed.conditionalRepeatingItems.idAdIndicator == nil)
    #expect(parsed.conditionalRepeatingItems.freeBaggageAllowance == nil)
    #expect(parsed.conditionalRepeatingItems.fastTrack == nil)
    // Should this be "N"?
    #expect(parsed.conditionalRepeatingItems.airlinePrivateData == "N*3000500TKG1")
    // Should this have the "N" chopped off?

    // It feels like they started including the fast-track field, but ommited the ID/AD / luggage-allowance fields.
    // AFAICT, that is... almost entirely made-up, and I doubt anything would read the "N" correctly, so
    // I think we can, in this case, just assume the "N" is part of the airline-private-data.
    // But it's weird.

    let printedData = try parser.print(parsed)
    #expect(printedData == input)
}

@Test
func fullBoardingPassRoundtripping() throws {
    // This, again, is a BP from my real collection. I have redacted the etix and FF numbers.
    // It is a rather complex one, with both conditional data and security data.
    let input = "M1KLAUSA/JAN          EPNRLOL LAXBOGAV 0089 165C001A0002 35E>5180 M    BAV              2A13412345678900 AV LH 112233445566778     Y*30600000K09  LHS    F^460MEUCIQDJ7OXFa3N0Ng9zqVS7oKZLgiFPl/oxz6agwHjXe7hboQIgEv6vwIxfNHhG2ranP3tk8/2qdbTHFJS/5tfrgQzH3Bg="

    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 1)
    #expect(parsed.name.lastName == "KLAUSA")
    #expect(parsed.name.firstName == "JAN")
    #expect(parsed.isEticket == "E")

    #expect(parsed.firstFlightSegment.PNR == "PNRLOL")
    #expect(parsed.firstFlightSegment.originAirportCode == "LAX")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "BOG")
    #expect(parsed.firstFlightSegment.carrierCode == "AV")
    #expect(parsed.firstFlightSegment.flightNumber == "0089")
    #expect(parsed.firstFlightSegment.julianFlightDate == 165)
    #expect(parsed.firstFlightSegment.cabinClass == "C")
    #expect(parsed.firstFlightSegment.seat == "001A")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0002 ")
    #expect(parsed.firstFlightSegment.passengerStatus == "3")

    #expect(parsed.conditionalData?.version == .v5)

    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance == "M")
    #expect(
        parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance?.isEmpty
            == true)
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == "AV")
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == [.emptyString])

    #expect(parsed.conditionalData?.conditionalRepeatingItems.airlineNumericCode == "134")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.documentNumber == "1234567890")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.selecteeIndicator == "0")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.internationalDocumentVerification?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems.marketingCarrierDesignator == "AV")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.frequentFlyerAirlineDesignator == "LH")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.frequentFlyerNumber == "112233445566778")

    #expect(parsed.conditionalData?.conditionalRepeatingItems.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems.fastTrack == "Y")
    #expect(parsed.conditionalData?.conditionalRepeatingItems.airlinePrivateData == "*30600000K09  LHS    F")

    #expect(parsed.securityData?.type == "4")
    #expect(parsed.securityData?.data == "MEUCIQDJ7OXFa3N0Ng9zqVS7oKZLgiFPl/oxz6agwHjXe7hboQIgEv6vwIxfNHhG2ranP3tk8/2qdbTHFJS/5tfrgQzH3Bg=")

    let printed = try parser.print(parsed)
    #expect(printed == input)
}

@Test
func unknownConditionalDataVersionRoundTripping() throws {
    let conditionalData = FirstSegmentConditionalItems(
        version: .unknown("9"),
        conditionalUniqueItems: .init(
            passengerDescription: "0"
        ),
        conditionalRepeatingItems: .init()
    )

    let printer = FirstSegmentConditionalItemsParser()
    let printed = try printer.print(conditionalData)
    let parsed = try printer.parse(printed)

    #expect(parsed.version == .unknown("9"))
    #expect(conditionalData == parsed)
    #expect(printed == ">901000")
}
