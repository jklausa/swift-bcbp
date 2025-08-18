struct RawBoardingPass: Sendable, Codable {
    var formatCode: String

    var legsCount: Int
    // currently unused

    var name: String

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

    var passengerStatus: String

    var variableSizeField: Int
}

// https://github.com/ncredinburgh/iata-parser/blob/master/src/main/java/com/ncredinburgh/iata/specs/CheckinSource.java

import Parsing

struct BoardingPassParser {

    static func parse(input: String) throws -> RawBoardingPass {
        let parser = Parse(input: Substring.self) { (formatCode, legsCount, name, isEticket, pnr, originAirportCode, destinationAirportCode, carrierCode, flightNumber, julianFlightDate, cabinClass, seat, sequenceNumber, passengerStatus, variableSizeField, _) in
            RawBoardingPass(
                formatCode: formatCode,
                legsCount: legsCount,
                name: name,
                isEticket: isEticket,
                pnr: pnr,
                originAirportCode: originAirportCode,
                destinationAirportCode: destinationAirportCode,
                carrierCode: carrierCode,
                flightNumber: flightNumber,
                julianFlightDate: julianFlightDate,
                cabinClass: cabinClass,
                seat: seat,
                sequenceNumber: sequenceNumber,
                passengerStatus: passengerStatus,
                variableSizeField: variableSizeField
            )
        } with: {
            First().map(String.init) // format code
            First().map(String.init).map { Int($0) ?? 0 } // legs count
            Prefix(20).map(String.init) // name?

            OneOf {
                "E".map { true }
                " ".map { false }
            }.replaceError(with: false)

            Prefix(7).map(String.init) // pnr

            Prefix(3).map(String.init) // origin
            Prefix(3).map(String.init) // destination

            Prefix(3).map(String.init) // carrier
            Prefix(5).map { $0.trimmingCharacters(in: .whitespaces) }.compactMap(Int.init) // flight number)

            Digits(3) // julian date

            OneOf {
                // Some of my Qatar Airways boarding passes have a cabin class field that just spells out the
                // whole cabin class, instead of using a single character, like the specs say.
                "BUSINESS".map { "Business" }
                "FIRST".map { "First" }
                First().map(String.init) // cabin class
            }
            Prefix(4).map(String.init) // seat

            Prefix(5).map { sequence in
                var sequence = sequence
                // My AirCanada boarding passes have a sequence number that ends with an "A" character,
                // which, contrary to one might expect, is not a hexadecimal "A", it seems to just be a suffix
                // (or maybe a boarding group indicator? both of mine have "A", so whatcha gonna do).
                if sequence.last == "A" {
                    sequence.removeLast()
                }

                return sequence.trimmingCharacters(in: .whitespaces)
            }.compactMap(Int.init)  // sequence number

            First().map(String.init) // passenger status

            TwoDigitHexStringToInt() // variable size field

            Optionally {
                Rest()
            }

        }

        let output = try parser.parse(input)
        print(output)

        return output

    }
}

struct TwoDigitHexStringToInt: Parser {
    typealias Input = Substring
    typealias Output = Int

    var body: some Parser<Input, Output> {
        Prefix(2).compactMap { Int.init($0, radix: 16) }
    }
}

extension TwoDigitHexStringToInt: ParserPrinter {
    func print(_ output: Int, into input: inout Substring) throws {
        let string = String(format: "%02X", output)
        input.prepend(contentsOf: string)
    }
}

