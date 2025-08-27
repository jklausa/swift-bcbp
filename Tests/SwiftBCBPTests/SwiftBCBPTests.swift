import Foundation
import Parsing
import Testing
@testable import SwiftBCBP

@Test("Test parsing", arguments: gatherTestCases())
func parseAndValidateFields(testCase: BoardingPassTestCase) async throws {
    do {
        let boardingPass = try RawBoardingPassParser().parse(testCase.input)

        if testCase.input.contains(">") {
            #expect(
                boardingPass.conditionalData != nil,
                "Failed parsing conditional data in:\n\(testCase.bracketedInput)",
            )
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

    #expect(parsedOutput.conditionalRepeatingItems?.airlineNumericCode == "220")
    #expect(parsedOutput.conditionalRepeatingItems?.documentNumber == "9999999999")
    #expect(parsedOutput.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(parsedOutput.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems?.marketingCarrierDesignator == "LH")
    #expect(parsedOutput.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "LH")
    #expect(parsedOutput.conditionalRepeatingItems?.frequentFlyerNumber == "999999999999999")
    #expect(parsedOutput.conditionalRepeatingItems?.fastTrack == "Y")
    #expect(parsedOutput.conditionalRepeatingItems?.airlinePrivateData == "*30600000K09  LHS    ")

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

    #expect(parsedOutput.conditionalRepeatingItems?.airlineNumericCode == "125")
    #expect(parsedOutput.conditionalRepeatingItems?.documentNumber == "9999999999")
    #expect(parsedOutput.conditionalRepeatingItems?.selecteeIndicator?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems?.internationalDocumentVerification == "1")
    #expect(parsedOutput.conditionalRepeatingItems?.marketingCarrierDesignator == "CX")
    #expect(parsedOutput.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "BA")
    #expect(parsedOutput.conditionalRepeatingItems?.frequentFlyerNumber == "99999999")
    #expect(parsedOutput.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsedOutput.conditionalRepeatingItems?.freeBaggageAllowance == "20K")
    #expect(parsedOutput.conditionalRepeatingItems?.fastTrack == "N")
    #expect(parsedOutput.conditionalRepeatingItems?.airlinePrivateData == "1BA")

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

    #expect(parsedWithFF.conditionalUniqueItems.passengerDescription?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.dateOfIssuance?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.documentType?.isEmpty == true)
    #expect(parsedWithFF.conditionalUniqueItems.airlineDesignatorOfIssuer == "KL")
    #expect(parsedWithFF.conditionalUniqueItems.bags == nil)

    #expect(parsedWithFF.conditionalRepeatingItems?.airlineNumericCode == "057")
    #expect(parsedWithFF.conditionalRepeatingItems?.documentNumber == "1111111111")
    #expect(parsedWithFF.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(
        parsedWithFF.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true,
    )
    #expect(parsedWithFF.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsedWithFF.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "AZ")
    #expect(parsedWithFF.conditionalRepeatingItems?.frequentFlyerNumber == "99999999")

    // Note the difference here between `== nil` and `?.isEmpty == true` previously.
    // `nil` means the field was not encoded at all, whereas `?.isEmpty == true` means
    // the field was encoded, but empty.
    #expect(parsedWithFF.conditionalRepeatingItems?.idAdIndicator == nil)
    #expect(parsedWithFF.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == nil)
    #expect(parsedWithFF.conditionalRepeatingItems?.fastTrack == nil)
    #expect(parsedWithFF.conditionalRepeatingItems?.airlinePrivateData == nil)

    let printedWithFF = try parser.print(parsedWithFF)
    #expect(printedWithFF == inputWithFF)

    let parsedWithoutFF = try parser.parse(inputWithoutFF)

    #expect(parsedWithoutFF.conditionalUniqueItems.passengerDescription?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.dateOfIssuance?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.documentType?.isEmpty == true)
    #expect(parsedWithoutFF.conditionalUniqueItems.airlineDesignatorOfIssuer == "KL")
    #expect(parsedWithoutFF.conditionalUniqueItems.bags == nil)

    #expect(parsedWithoutFF.conditionalRepeatingItems?.airlineNumericCode == "057")
    #expect(parsedWithoutFF.conditionalRepeatingItems?.documentNumber == "9999999999")
    #expect(parsedWithoutFF.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(parsedWithoutFF.conditionalRepeatingItems?.internationalDocumentVerification == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.marketingCarrierDesignator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.frequentFlyerNumber == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.idAdIndicator == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.freeBaggageAllowance == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.fastTrack == nil)
    #expect(parsedWithoutFF.conditionalRepeatingItems?.airlinePrivateData == nil)

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

    #expect(parsed.conditionalUniqueItems.passengerDescription?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalUniqueItems.sourceOfIssuance == "M")

    // Again, note the difference between `== nil` and `?.isEmpty == true` here.

    #expect(parsed.conditionalUniqueItems.dateOfIssuance == nil)
    #expect(parsed.conditionalUniqueItems.documentType == nil)
    #expect(parsed.conditionalUniqueItems.airlineDesignatorOfIssuer == nil)
    #expect(parsed.conditionalUniqueItems.bags == nil)

    #expect(parsed.conditionalRepeatingItems?.airlineNumericCode == "074")
    #expect(parsed.conditionalRepeatingItems?.documentNumber == "6666666666")
    #expect(parsed.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "AZ")
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerNumber == "0002222222")
    #expect(parsed.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.fastTrack == "Y")
    #expect(parsed.conditionalRepeatingItems?.airlinePrivateData == nil)

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

    #expect(parsed.conditionalRepeatingItems?.airlineNumericCode?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.documentNumber?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "AB")
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerNumber == "777777777")
    #expect(parsed.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalRepeatingItems?.fastTrack == "Y")
    #expect(parsed.conditionalRepeatingItems?.airlinePrivateData == "11G")

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

    #expect(parsed.conditionalRepeatingItems?.airlineNumericCode == "117")
    #expect(parsed.conditionalRepeatingItems?.documentNumber == "3333333333")
    #expect(parsed.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(
        parsed.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty
            == true,
    )
    #expect(parsed.conditionalRepeatingItems?.marketingCarrierDesignator == "SK")
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "TK")
    #expect(parsed.conditionalRepeatingItems?.frequentFlyerNumber == "555555555")

    #expect(parsed.conditionalRepeatingItems?.idAdIndicator == nil)
    #expect(parsed.conditionalRepeatingItems?.freeBaggageAllowance == nil)
    #expect(parsed.conditionalRepeatingItems?.fastTrack == nil)
    // Should this be "N"?
    #expect(parsed.conditionalRepeatingItems?.airlinePrivateData == "N*3000500TKG1")
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
            == true,
    )
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == "AV")
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == [.emptyString])

    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlineNumericCode == "134")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.documentNumber == "1234567890")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.marketingCarrierDesignator == "AV")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == "LH")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerNumber == "112233445566778")

    #expect(parsed.conditionalData?.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.fastTrack == "Y")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlinePrivateData == "*30600000K09  LHS    F")

    #expect(parsed.securityData?.type == "4")
    #expect(parsed.securityData?
        .data == "MEUCIQDJ7OXFa3N0Ng9zqVS7oKZLgiFPl/oxz6agwHjXe7hboQIgEv6vwIxfNHhG2ranP3tk8/2qdbTHFJS/5tfrgQzH3Bg=")

    let printed = try parser.print(parsed)
    #expect(printed == input)
}

@Test
func unknownConditionalDataVersionRoundTripping() throws {
    let conditionalData = FirstSegmentConditionalItems(
        version: .unknown("9"),
        conditionalUniqueItems: .init(
            passengerDescription: "0",
        ),
        conditionalRepeatingItems: .init(),
    )

    let printer = FirstSegmentConditionalItemsParser()
    let printed = try printer.print(conditionalData)
    let parsed = try printer.parse(printed)

    #expect(parsed.version == .unknown("9"))
    #expect(conditionalData == parsed)
    #expect(printed == ">901000")
}

@Test
func knownIssueLATAM() throws {
    // This corresponds to a `lK5p0BOtTw66-oDpYyI6pmwB920=.pkpass/pass.json` I have,
    // which seems to have a completely busted conditional data section.
    // I can't figure out a way to even _interepret_ the data, just by looking at it, let alone write
    // code to parse it.
    // The `99999999` is a redacted FF number, and the `LA ` previously would suggest that it would be a LATAM FF#,
    // but it was, in fact, a BA FF#, making this even more confusing.
    //
    // Another issue, that is much harder to spot — the specified length of the data after the first flight segment is
    // not
    // matching up with what actually is there. The BP says `0x3D`, but the actual data is 11 characters short.
    let input = "M1KLAUSA/JAN          EPNRRNP BOGSCLLA 0575 167Y013A0069 13D>10B0MM9167BLA 29 1045LA 99999999            111"
    let parser = RawBoardingPassParser()

    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 1)
    #expect(parsed.name.lastName == "KLAUSA")
    #expect(parsed.name.firstName == "JAN")
    #expect(parsed.isEticket == "E")

    #expect(parsed.firstFlightSegment.PNR == "PNRRNP")
    #expect(parsed.firstFlightSegment.originAirportCode == "BOG")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "SCL")

    #expect(parsed.firstFlightSegment.carrierCode == "LA")
    #expect(parsed.firstFlightSegment.flightNumber == "0575")

    #expect(parsed.firstFlightSegment.julianFlightDate == 167)
    #expect(parsed.firstFlightSegment.cabinClass == "Y")

    #expect(parsed.firstFlightSegment.seat == "013A")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0069 ")

    #expect(parsed.firstFlightSegment.passengerStatus == "1")

    #expect(parsed.conditionalData?.version == .v1)

    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn == "M")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance == "M")
    #expect(parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance == "9167")
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == "LA")

    withKnownIssue {
        #expect(
            parsed.conditionalData?.conditionalRepeatingItems != nil,
            "Failed parsing conditional repeating data in:\n\(input)",
        )
    }
}

@Test
func multiLegFlight() throws {
    // Test input from: https://alee91.pythonanywhere.com

    let input = "M2PHLIPS/AAAAAA       EAAAAAA ZYRCDGAF 7186 092Y013A0020 348>5180      B1A              2A13123004911111                           NAAAAAA CDGHNDJL 0046 092Y050K0039 32C2A1312300491111                            N"

    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 2)
    #expect(parsed.name.lastName == "PHLIPS")
    #expect(parsed.name.firstName == "AAAAAA")
    #expect(parsed.isEticket == "E")

    #expect(parsed.firstFlightSegment.PNR == "AAAAAA")
    #expect(parsed.firstFlightSegment.originAirportCode == "ZYR")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "CDG")
    #expect(parsed.firstFlightSegment.carrierCode == "AF")
    #expect(parsed.firstFlightSegment.flightNumber == "7186")
    #expect(parsed.firstFlightSegment.julianFlightDate == 092)
    #expect(parsed.firstFlightSegment.cabinClass == "Y")
    #expect(parsed.firstFlightSegment.seat == "013A")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0020 ")
    #expect(parsed.firstFlightSegment.passengerStatus == "3")

    #expect(parsed.conditionalData?.version == .v5)

    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(
        parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance?.isEmpty
            == true,
    )
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == "1A")
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == [.emptyString])

    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlineNumericCode == "131")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.documentNumber == "2300491111")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.selecteeIndicator == "1")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty == true
    )
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerAirlineDesignator?.isEmpty == true,
    )
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerNumber?.isEmpty == true,
    )
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.fastTrack == "N")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlinePrivateData == nil)

    #expect(parsed.otherSegments?.count == 1)

    let secondSegment = parsed.otherSegments?.first

    #expect(secondSegment?.segment.PNR == "AAAAAA")
    #expect(secondSegment?.segment.originAirportCode == "CDG")
    #expect(secondSegment?.segment.destinationAirportCode == "HND")
    #expect(secondSegment?.segment.carrierCode == "JL")
    #expect(secondSegment?.segment.flightNumber == "0046")
    #expect(secondSegment?.segment.julianFlightDate == 092)
    #expect(secondSegment?.segment.cabinClass == "Y")
    #expect(secondSegment?.segment.seat == "050K")
    #expect(secondSegment?.segment.sequenceNumber == "0039 ")
    #expect(secondSegment?.segment.passengerStatus == "3")

    #expect(secondSegment?.repeatingItems?.airlineNumericCode == "131")
    #expect(secondSegment?.repeatingItems?.documentNumber == "2300491111")
    #expect(secondSegment?.repeatingItems?.selecteeIndicator?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(
        secondSegment?.repeatingItems?.frequentFlyerAirlineDesignator?.isEmpty
            == true,
    )
    #expect(secondSegment?.repeatingItems?.frequentFlyerNumber?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.fastTrack == "N")
    #expect(secondSegment?.repeatingItems?.airlinePrivateData == nil)

    #expect(parsed.securityData == nil)
    #expect(parsed.rest == nil)
}

@Test
func multiLegSpecExample() async throws {
    // This is the example from the v5 of the BCBP spec, verabatim.
    let input = "M2DESMARAIS/LUC       EABC123 YULFRAAC 0834 226F001A0025 14D>6181WW6225BAC 00141234560032A0141234567890 1AC AC 1234567890123    20KYLX58ZDEF456 FRAGVALH 3664 227C012C0002 12E2A0140987654321 1AC AC 1234567890123    2PCNWQ^164GIWVC5EH7JNT684FVNJ91W2QA4DVN5J8K4F0L0GEQ3DF5TGBN8709HKT5D3DW3GBHFCVHMY7J5T6HFR41W2QA4DVN5J8K4F0L0GE"

    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    // I'm not sure if I like this style of testing?
    // Having it broken down field by field makes it easier to see what is failing.
    // Doing this however, let's us verify that _manually_ created instances also encode to the expected value,
    // so having _one_ could be useful.
    let created = RawBoardingPass(
        formatCode: "M",
        legsCount: 2,
        name: .init(lastName: "DESMARAIS", firstName: "LUC"),
        isEticket: "E",
        firstFlightSegment: .init(
            PNR: "ABC123",
            originAirportCode: "YUL",
            destinationAirportCode: "FRA",
            carrierCode: "AC",
            flightNumber: "0834",
            julianFlightDate: 226,
            cabinClass: "F",
            seat: "001A",
            sequenceNumber: "0025 ",
            passengerStatus: "1",
        ),
        conditionalData: .init(
            version: .v6,
            conditionalUniqueItems: .init(
                passengerDescription: "1",
                sourceOfCheckIn: "W",
                sourceOfIssuance: "W",
                dateOfIssuance: "6225",
                documentType: "B",
                airlineDesignatorOfIssuer: "AC",
                bags: [.registeredBag(0_014_123_456_003)],
            ),
            conditionalRepeatingItems: .init(
                airlineNumericCode: "014",
                documentNumber: "1234567890",
                selecteeIndicator: "",
                internationalDocumentVerification: "1",
                marketingCarrierDesignator: "AC",
                frequentFlyerAirlineDesignator: "AC",
                frequentFlyerNumber: "1234567890123",
                idAdIndicator: "",
                freeBaggageAllowance: "20K",
                fastTrack: "Y",
                airlinePrivateData: "LX58Z",
            ),
        ),
        otherSegments: [
            .init(
                segment: .init(
                    PNR: "DEF456",
                    originAirportCode: "FRA",
                    destinationAirportCode: "GVA",
                    carrierCode: "LH",
                    flightNumber: "3664",
                    julianFlightDate: 227,
                    cabinClass: "C",
                    seat: "012C",
                    sequenceNumber: "0002 ",
                    passengerStatus: "1",
                ),
                repeatingItems: .init(
                    airlineNumericCode: "014",
                    documentNumber: "0987654321",
                    selecteeIndicator: "",
                    internationalDocumentVerification: "1",
                    marketingCarrierDesignator: "AC",
                    frequentFlyerAirlineDesignator: "AC",
                    frequentFlyerNumber: "1234567890123",
                    idAdIndicator: "",
                    freeBaggageAllowance: "2PC",
                    fastTrack: "N",
                    airlinePrivateData: "WQ",
                ),
            )
        ],
        securityData: .init(
            type: "1",
            data: "GIWVC5EH7JNT684FVNJ91W2QA4DVN5J8K4F0L0GEQ3DF5TGBN8709HKT5D3DW3GBHFCVHMY7J5T6HFR41W2QA4DVN5J8K4F0L0GE",
        ),
        rest: nil,
    )

    #expect(parsed == created)

    let printed = try parser.print(created)

    #expect(printed == input)
}

@Test
func realWorldTwoSegment() throws {
    // This is not from my collection, but a example I found online, when someone posted their BP on a forum.
    // I have redacted the name, PNR, etix and FF numbers.
    let input = "M2GUY/SOME            EABC123 LAXCDGAF 4097 356J070A0174 347>2180      B                29             0                           ABC123 CDGTLSAF 7794 357Y006A0006 32B29             0    AF 1112223334/P        "

    let parser = RawBoardingPassParser()

    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 2)
    #expect(parsed.name.lastName == "GUY")
    #expect(parsed.name.firstName == "SOME")
    #expect(parsed.isEticket == "E")

    #expect(parsed.firstFlightSegment.PNR == "ABC123")
    #expect(parsed.firstFlightSegment.originAirportCode == "LAX")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "CDG")
    #expect(parsed.firstFlightSegment.carrierCode == "AF")
    #expect(parsed.firstFlightSegment.flightNumber == "4097")
    #expect(parsed.firstFlightSegment.julianFlightDate == 356)
    #expect(parsed.firstFlightSegment.cabinClass == "J")
    #expect(parsed.firstFlightSegment.seat == "070A")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0174 ")
    #expect(parsed.firstFlightSegment.passengerStatus == "3")

    #expect(parsed.conditionalData?.version == .v2)

    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == "0")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance?.isEmpty == true)
    #expect(
        parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance?.isEmpty
            == true,
    )
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == [.emptyString])

    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlineNumericCode?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.documentNumber?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.selecteeIndicator == "0")
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty
            == true,
    )
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerAirlineDesignator?.isEmpty == true,
    )
    #expect(
        parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerNumber?.isEmpty == true,
    )
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.fastTrack == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlinePrivateData == nil)

    #expect(parsed.otherSegments?.count == 1)

    let secondSegment = parsed.otherSegments?.first

    #expect(secondSegment?.segment.PNR == "ABC123")
    #expect(secondSegment?.segment.originAirportCode == "CDG")
    #expect(secondSegment?.segment.destinationAirportCode == "TLS")
    #expect(secondSegment?.segment.carrierCode == "AF")
    #expect(secondSegment?.segment.flightNumber == "7794")
    #expect(secondSegment?.segment.julianFlightDate == 357)
    #expect(secondSegment?.segment.cabinClass == "Y")
    #expect(secondSegment?.segment.seat == "006A")
    #expect(secondSegment?.segment.sequenceNumber == "0006 ")
    #expect(secondSegment?.segment.passengerStatus == "3")

    #expect(secondSegment?.repeatingItems?.airlineNumericCode?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.documentNumber?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.selecteeIndicator == "0")
    #expect(secondSegment?.repeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.frequentFlyerAirlineDesignator == "AF")
    #expect(secondSegment?.repeatingItems?.frequentFlyerNumber == "1112223334/P")
    #expect(secondSegment?.repeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(secondSegment?.repeatingItems?.fastTrack == nil)
    #expect(secondSegment?.repeatingItems?.airlinePrivateData == nil)

    #expect(parsed.securityData == nil)
    #expect(parsed.rest == nil)

    withKnownIssue {
        // This seems to try to print out `00` as the header for the conditional data, instead of actual value (47).
        // I'm not sure why, but the whole printing is not fully tested yet, so leaving it in known-issue for now.
        let printed = try parser.print(parsed)
        #expect(printed == input)
    }
}

@Test
func airBerlinYoshiEdgeCase() throws {
    // This is a BP donated by @notjosh.
    // As always, personal info has been redacted.
    // There are... multiple issues with this BP.
    // It has no PNR, which is... surprising, but at least it doesn't skip the entire field.
    // It has an out-of-spec way of specifing the flight date, using `  0` instead of `001` for Jan 1st.
    // Then, the conditional data section is also borked: it is almost perfectly valid, but the frequent flyer airline
    // is specified as "AB", instead
    // of "AB " (with a trailing space). This messes up the parsing of the rest of the fields, making it impossible to
    // parse correctly.
    let input = "M1NOT/JOSH            E       CTATXLAB 8783   1Y013D0001 162>5321OR6365BAZ                                        2A7123987654321 0   AB123456789           N"
    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 1)
    #expect(parsed.name.lastName == "NOT")
    #expect(parsed.name.firstName == "JOSH")
    #expect(parsed.isEticket == "E")

    #expect(parsed.firstFlightSegment.PNR.isEmpty == true)
    #expect(parsed.firstFlightSegment.originAirportCode == "CTA")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "TXL")

    #expect(parsed.firstFlightSegment.carrierCode == "AB")
    #expect(parsed.firstFlightSegment.flightNumber == "8783")

    // Note that they have not padded this as per spec, to `001`.
    #expect(parsed.firstFlightSegment.julianFlightDate == 1)
    #expect(parsed.firstFlightSegment.cabinClass == "Y")

    #expect(parsed.firstFlightSegment.seat == "013D")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0001 ")

    #expect(parsed.firstFlightSegment.passengerStatus == "1")

    #expect(parsed.conditionalData?.version == .v5)

    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == "1")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn == "O")
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance == "R")
    #expect(parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance == "6365")
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == "B")
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == "AZ")
    #expect(
        parsed.conditionalData?.conditionalUniqueItems.bags == [
            .emptyString,
            .emptyString,
            .emptyString
        ],
    )

    withKnownIssue {
        // I'd like to maybe try detecting this failure mode and fixing it up, but that's a task for a future me.
        #expect(
            parsed.conditionalData?.conditionalRepeatingItems != nil,
            "Failed parsing conditional repeating data in:\n\(input)",
        )
    }
    #expect(parsed.rest == "2A7123987654321 0   AB123456789           N")
}

@Test
func wizzAirEdgeCase() throws {
    // Another BP from @notjosh.
    // This one is (seemingly?) to standard, but has weird in that it completely omits the "unique" conditional data
    // section,
    // but still includes the "repeating" section, filled with blanks for everything other than the fast track.
    // As a bonus point, it does not indicate whether it's an E-Ticket, which would imply that it's not, which it
    // absolutely was.
    let input = "M1NOT/JOSH             PNR123 BUDSXFW6 2315 197Y012A0011 130>5002A                                         N"
    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 1)
    #expect(parsed.name.lastName == "NOT")
    #expect(parsed.name.firstName == "JOSH")
    #expect(parsed.isEticket.isEmpty == true)

    #expect(parsed.firstFlightSegment.PNR == "PNR123")
    #expect(parsed.firstFlightSegment.originAirportCode == "BUD")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "SXF")
    #expect(parsed.firstFlightSegment.carrierCode == "W6")
    #expect(parsed.firstFlightSegment.flightNumber == "2315")
    #expect(parsed.firstFlightSegment.julianFlightDate == 197)
    #expect(parsed.firstFlightSegment.cabinClass == "Y")
    #expect(parsed.firstFlightSegment.seat == "012A")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0011 ")
    #expect(parsed.firstFlightSegment.passengerStatus == "1")

    #expect(parsed.conditionalData?.version == .v5)

    // Note that these are all `nil`, but the section itself is present! That's a meaningful distinction,
    // unfortunately.
    #expect(parsed.conditionalData?.conditionalUniqueItems != nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == nil)

    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlineNumericCode?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.documentNumber?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.selecteeIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.internationalDocumentVerification?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.marketingCarrierDesignator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerAirlineDesignator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerNumber?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.idAdIndicator?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.freeBaggageAllowance?.isEmpty == true)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.fastTrack == "N")

    #expect(parsed.rest == nil)
}

@Test
func norwegianConditionalDataEdgeCase() throws {
    // Another BP from @notjosh.
    // This is a fun one.
    // This omits the eticket ("document") number from the conditional data section, instead stuffing it inside
    // of the "Airline Private Data" field.
    // Why?
    // Because computers suck, that's why.
    // This is also a fun one since it also has both "unique" and "repeating" conditional data section completely
    // omitted.
    // It also does the same thing as W6 above, and doesn't correctly indicate whether it's an eticket or not.
    let input = "M1NOT/JOSH             123PNR SXFOSLDY 1105 166Y027F0008 114>30000328-1234567890"
    let parser = RawBoardingPassParser()
    let parsed = try parser.parse(input)

    #expect(parsed.formatCode == "M")
    #expect(parsed.legsCount == 1)
    #expect(parsed.name.lastName == "NOT")
    #expect(parsed.name.firstName == "JOSH")
    #expect(parsed.isEticket.isEmpty == true)

    #expect(parsed.firstFlightSegment.PNR == "123PNR")
    #expect(parsed.firstFlightSegment.originAirportCode == "SXF")
    #expect(parsed.firstFlightSegment.destinationAirportCode == "OSL")
    #expect(parsed.firstFlightSegment.carrierCode == "DY")
    #expect(parsed.firstFlightSegment.flightNumber == "1105")
    #expect(parsed.firstFlightSegment.julianFlightDate == 166)
    #expect(parsed.firstFlightSegment.cabinClass == "Y")
    #expect(parsed.firstFlightSegment.seat == "027F")
    #expect(parsed.firstFlightSegment.sequenceNumber == "0008 ")
    #expect(parsed.firstFlightSegment.passengerStatus == "1")

    #expect(parsed.conditionalData?.version == .v3)

    // Note that these are all `nil`, but the section itself is present! That's a meaningful distinction,
    // unfortunately.
    #expect(parsed.conditionalData?.conditionalUniqueItems != nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.passengerDescription == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfCheckIn == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.sourceOfIssuance == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.dateOfIssuance == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.documentType == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.airlineDesignatorOfIssuer == nil)
    #expect(parsed.conditionalData?.conditionalUniqueItems.bags == nil)

    // Compare and contrast with the BP above (`wizzAirEdgeCase`), which also had (semantically) missing unique
    // conditional data,
    // but the section was present, just filled with blanks.
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlineNumericCode == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.documentNumber == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.selecteeIndicator == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.internationalDocumentVerification == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.marketingCarrierDesignator == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerAirlineDesignator == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.frequentFlyerNumber == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.idAdIndicator == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.freeBaggageAllowance == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.fastTrack == nil)
    #expect(parsed.conditionalData?.conditionalRepeatingItems?.airlinePrivateData == "328-1234567890")

    #expect(parsed.rest == nil)
}
