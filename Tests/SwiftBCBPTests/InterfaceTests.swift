import Foundation
import Testing
import SwiftBCBP

@Test
func publicInterface() throws {
    // Test the public interface for the API makes sense.
    let specBP = "M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 226F001A0025 100"

    let parsedBP = try RawBoardingPassParser().parse(specBP)

    #expect(parsedBP.formatCode == "M")
    #expect(parsedBP.legsCount == 1)

    #expect(parsedBP.name == .init(lastName: "DESMARAIS", firstName: "LUC"))

    #expect(parsedBP.firstFlightSegment.PNR == "ABC123")
    #expect(parsedBP.firstFlightSegment.originAirportCode == "YUL")
    #expect(parsedBP.firstFlightSegment.destinationAirportCode == "FRA")
    #expect(parsedBP.firstFlightSegment.carrierCode == "AC")

    #expect(parsedBP.firstFlightSegment.flightNumber == "0834")

    #expect(parsedBP.firstFlightSegment.julianFlightDate == 226)

    #expect(parsedBP.firstFlightSegment.cabinClass == "F")

    #expect(parsedBP.firstFlightSegment.seat == "001A")
    #expect(parsedBP.firstFlightSegment.sequenceNumber == "0025 ")

    #expect(parsedBP.firstFlightSegment.passengerStatus == "1")

    #expect(parsedBP.conditionalData == nil)
    #expect(parsedBP.otherSegments == nil)
    #expect(parsedBP.securityData == nil)

    withKnownIssue {
        #expect(parsedBP.rest == nil)
    }
}
