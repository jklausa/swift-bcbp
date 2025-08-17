struct RawBoardingPass: Sendable, Codable {
    var formatCode: String

    var legsCount: Int
    // currently unused

    var name: String
    var printableName: String { name.split(separator: "/").reversed().joined() }
    // Does this make sense?

    var isEticket: Bool

    var pnr: String

    var originAirportCode: String
    var destinationAirportCode: String

    var carrierCode: String
    var flightNumber: Int

    var julianFlightDate: Int

    var cabinClass: String

    var seat: String
    var sequenceNumber: Int

    var passengerStatus: Int

    var variableSizeField: Int
}

// https://github.com/ncredinburgh/iata-parser/blob/master/src/main/java/com/ncredinburgh/iata/specs/CheckinSource.java

import Parsing

struct BoardingPassParser {

    static func parse(input: String) throws -> RawBoardingPass? {
        let parser = Parse(input: Substring.self) {
            First() // format
            First() // count
            Prefix(20) // name?
            First() // etix
            Prefix(7) // pnr

            Prefix(3) // origin
            Prefix(3) // destination

            Prefix(3) // carrier
            Prefix(5).map { $0.trimmingCharacters(in: .whitespaces) }.map(Int.init) // flight number)

            Digits(3) // julian date

            First() // cabin class
            Prefix(4) // seat

            Prefix(5).map { $0.trimmingCharacters(in: .whitespaces).map(Int.init) } // sequence number

            First() // passenger status

            Rest()
        }

        let output = try parser.parse(input)
        print(output)

        return nil
    }


}
