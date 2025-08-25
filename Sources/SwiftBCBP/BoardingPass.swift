struct RawBoardingPass: Sendable, Codable {
    var formatCode: String

    var legsCount: Int
    // currently unused

    var name: String

    var isEticket: Bool

    var pnr: PNR

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

    var conditionalData: VersionSixConditionalItems?

    var securityData: SecurityData?
}

// https://github.com/ncredinburgh/iata-parser/blob/master/src/main/java/com/ncredinburgh/iata/specs/CheckinSource.java

import Parsing

struct BoardingPassParser {

    static func parse(input: String) throws -> RawBoardingPass {
        let parser = Parse(input: Substring.self) { (formatCode, legsCount, name, isEticket, pnr, originAirportCode, destinationAirportCode, carrierCode, flightNumber, julianFlightDate, cabinClass, seat, sequenceNumber, passengerStatus, variableSizeField, conditionalData, security, _) in

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
                variableSizeField: variableSizeField,
                conditionalData: conditionalData,
                securityData: security
            )
        } with: {
            First().map(String.init) // format code
            First().map(String.init).map { Int($0) ?? 0 } // legs count
            Prefix(20).map(String.init) // name?

            OneOf {
                "E".map { true }
                " ".map { false }
            }.replaceError(with: false)

            PNRParser()

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
                ConditionalItemsParser()
            }

            Optionally {
                Skip { Prefix(while: { $0 != "^" }) }
                // I think this should be not needed after all the other printer/parsers are in place.
                SecurityDataParser()
            }

            Optionally {
                Rest()
            }

        }

        let output = try parser.parse(input)
        print(output)

        return output

    }
}

struct PNR: Codable, Sendable, Hashable {
    var pnr: String
    private(set) var rawPNR: String
}

struct PNRParser: ParserPrinter {
    var body: some Parser<Substring, PNR> {
        Parse {
            PNR(
                pnr: $0.trimmingCharacters(in: .whitespaces),
                rawPNR: String($0)
            )
        } with: {
            Prefix(7)
        }
    }

    // This needs to just right-pad the PNR, instead of outputting it raw.
    // We actually need a generic purpose "right-pad" printer.
    // I don't love the `raw` thing at all, but for now it should be fine.
    func print(_ output: PNR, into input: inout Substring) throws {
        input.prepend(contentsOf: output.rawPNR)
    }
}

struct TwoDigitHexStringToInt: ParserPrinter {
    var body: some Parser<Substring, Int> {
        Prefix(2).compactMap { Int.init($0, radix: 16) }
    }

    func print(_ output: Int, into input: inout Substring) throws {
        let string = String(format: "%02X", output)
        input.prepend(contentsOf: string)
    }
}

// MARK: - Security Data
public struct SecurityData: Codable, Sendable, Hashable {
    var type: String
    var length: Int
    var data: String

    // TODO: Should we calculate the length, instead of having a field for it?
}

public struct SecurityDataParser: ParserPrinter {
    public var body: some ParserPrinter<Substring, SecurityData> {
        ParsePrint(.memberwise(SecurityData.init)) {
            "^"
            Prefix(1).map(.string)
            TwoDigitHexStringToInt()
            Rest().map(.string)
        }
    }
}

// MARK: - Conditional items section

public struct ConditionalItemsParser: Parser {
    public var body: some Parser<Substring, VersionSixConditionalItems> {
        Parse {
            (
             passengerDescription: String,
             sourceOfCheckin: String,
             sourceOfIssuance: String,
             dateOfIssuance: String,
             documentType: String,
             airlineDesignationOfIssuer: String,
             baggageTags: BaggageTags?,
             secondHexLength: Int,
             airlineNumericCode: String,
             documentNumber: String,
             selecteeIndicator: String,
             docVerification: String?,
             marketingCarrierDesignator: String?,
             ffAirline: String?,
             ffNumber: String?,
             idADIndicator: String?,
             luggageAllowance: String?,
             fastTrack: String?,
             airlinePrivateData: String?) in

            VersionSixConditionalItems(
                passengerDescription: passengerDescription,
                sourceOfCheckIn: sourceOfCheckin,
                sourceOfIssuance: sourceOfIssuance,
                dateOfIssuance: dateOfIssuance,
                documentType: documentType,
                airlineDesignatorOfIssuer: airlineDesignationOfIssuer,
                firstBagNumber: baggageTags?.firstBagNumber ?? 0,
                secondBagNumber: baggageTags?.secondBagNumber ?? 0,
                thirdBagNumber: baggageTags?.thirdBagNumber ?? 0,
                airlineNumericCode: airlineNumericCode,
                documentNumber: documentNumber,
                selecteeIndicator: selecteeIndicator,
                internationalDocumentVerification: docVerification ?? "",
                marketingCarrierDesignator: marketingCarrierDesignator ?? "",
                frequentFlyerAirlineDesignator: ffAirline ?? "",
                frequentFlyerNumber: ffNumber ?? "",
                idAdIndicator: idADIndicator ?? "",
                freeBaggageAllowance: luggageAllowance ?? "",
                fastTrack: fastTrack ?? "",
                airlinePrivateData: airlinePrivateData
            )

        } with: {
            OneOf {
                ">6"
                ">7"
                ">8"
                // V6 and V7 and V8 are (mostly) the same structure-wise, they just allow for additional states in some fields like gender markers, and change semantics of a couple of things (luggage registration plates)
            }

            TwoDigitHexStringToInt()
                .flatMap { hexLength in
                    // Take the length, and prefix
                    Prefix(hexLength)
                }
                .pipe {
                    Prefix(1).map(.string) // passenger description
                    Prefix(1).map(.string) // source of check-in
                    Prefix(1).map(.string) // source of issuance
                    Prefix(4).map(.string) // date of issuance
                    Prefix(1).map(.string) // document type
                    Prefix(3).map(.string) // airline designator of issuer

                    Optionally {
                        BaggageTagParser()
                    }
                }

            TwoDigitHexStringToInt()

            Prefix(3).map(.string) // airline numeric code
            Prefix(10).map(.string) // document number

            Prefix(1).map(.string) // selectee indicator
            Optionally {
                Prefix(1).map(.string) // international document verification
            }

            Optionally {
                Prefix(3).map(.string) // marketing carrier designator
            }

            Optionally {
                Prefix(3).map(.string) // frequent flyer airline designator
            }
            Optionally {
                Prefix(16).map(.string) // frequent flyer number
            }
            Optionally {
                Prefix(1).map(.string) // ID/AD indicator
            }
            Optionally {
                Prefix(3).map(.string) // free baggage allowance
            }
            Optionally {
                Prefix(1).map(.string) // fast track
            }

            Optionally {
                Rest().map(.string) // airline private data
            }
        }
    }
}

struct BaggageTags: Sendable, Codable, Hashable {
    var firstBagNumber: Int?
    var secondBagNumber: Int?
    var thirdBagNumber: Int?
}

struct BaggageTagParser: Parser {

    var body: some Parser<Substring, BaggageTags> {
        Parse {  (bags: [Int]) -> BaggageTags in
            let second: Int? = if bags.count > 1 { bags[1] } else { nil }
            let third: Int? = if bags.count > 2 { bags[2] } else { nil }
            return BaggageTags(
                firstBagNumber: bags.first,
                secondBagNumber: second,
                thirdBagNumber: third
            )
        } with: {
            // I have a CX boarding pass with zero bags, that are encoded as 39 spaces.
            // Nobody else does it like that but heyo!
            Many(1...3) {
                OneOf {
                    "             ".map { 0 }
                    Digits(13)
                }
            }
        }
    }
}

public struct VersionSixConditionalItems: Sendable, Codable, Hashable {
    var passengerDescription: String
    var sourceOfCheckIn: String
    var sourceOfIssuance: String
    var dateOfIssuance: String
    var documentType: String
    var airlineDesignatorOfIssuer: String
    var firstBagNumber: Int
    var secondBagNumber: Int
    var thirdBagNumber: Int

    var airlineNumericCode: String // etix?
    var documentNumber: String

    var selecteeIndicator: String
    var internationalDocumentVerification: String

    var marketingCarrierDesignator: String

    var frequentFlyerAirlineDesignator: String
    var frequentFlyerNumber: String

    var idAdIndicator: String
    var freeBaggageAllowance: String
    var fastTrack: String

    var airlinePrivateData: String?

    public init(passengerDescription: String, sourceOfCheckIn: String, sourceOfIssuance: String, dateOfIssuance: String, documentType: String, airlineDesignatorOfIssuer: String, firstBagNumber: Int, secondBagNumber: Int, thirdBagNumber: Int, airlineNumericCode: String, documentNumber: String, selecteeIndicator: String, internationalDocumentVerification: String, marketingCarrierDesignator: String, frequentFlyerAirlineDesignator: String, frequentFlyerNumber: String, idAdIndicator: String, freeBaggageAllowance: String, fastTrack: String, airlinePrivateData: String? = nil) {
        self.passengerDescription = passengerDescription
        self.sourceOfCheckIn = sourceOfCheckIn
        self.sourceOfIssuance = sourceOfIssuance
        self.dateOfIssuance = dateOfIssuance
        self.documentType = documentType
        self.airlineDesignatorOfIssuer = airlineDesignatorOfIssuer
        self.firstBagNumber = firstBagNumber
        self.secondBagNumber = secondBagNumber
        self.thirdBagNumber = thirdBagNumber
        self.airlineNumericCode = airlineNumericCode
        self.documentNumber = documentNumber
        self.selecteeIndicator = selecteeIndicator
        self.internationalDocumentVerification = internationalDocumentVerification
        self.marketingCarrierDesignator = marketingCarrierDesignator
        self.frequentFlyerAirlineDesignator = frequentFlyerAirlineDesignator
        self.frequentFlyerNumber = frequentFlyerNumber
        self.idAdIndicator = idAdIndicator
        self.freeBaggageAllowance = freeBaggageAllowance
        self.fastTrack = fastTrack
        self.airlinePrivateData = airlinePrivateData
    }
}

