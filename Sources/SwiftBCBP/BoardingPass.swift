// MARK: - RawBoardingPass

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

    var conditionalData: FirstSegmentConditionalItems?

    var securityData: SecurityData?
}

// https://github.com/ncredinburgh/iata-parser/blob/master/src/main/java/com/ncredinburgh/iata/specs/CheckinSource.java

import Parsing

// MARK: - BoardingPassParser

enum BoardingPassParser {
    static func parse(input: String) throws -> RawBoardingPass {
        let parser = Parse(input: Substring
            .self)
        { formatCode, legsCount, name, isEticket, pnr, originAirportCode, destinationAirportCode, carrierCode, flightNumber, julianFlightDate, cabinClass, seat, sequenceNumber, passengerStatus, variableSizeField, conditionalData, security, _ in
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
                securityData: security,
            )
        } with: {
            First().map(String.init) // format code
            First().map(String.init).map { Int($0) ?? 0 } // legs count
            Prefix(20).map(String.init) // name?

            OneOf {
                "E".map { true }
                " ".map { false }
            }.replaceError(with: false)

            RightPaddedStringParser(length: 7)

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
            }
            .compactMap(Int.init) // sequence number

            First().map(String.init) // passenger status

            TwoDigitHexStringToInt() // variable size field

            Optionally {
                FirstSegmentConditionalItemsParser()
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

        return output
    }
}

// MARK: - SecurityData

public struct SecurityData: Codable, Sendable, Hashable {
    var type: String
    var length: Int
    var data: String

    // TODO: Should we calculate the length, instead of having a field for it?
}

// MARK: - SecurityDataParser

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

// MARK: - FirstSegmentConditionalItems

struct FirstSegmentConditionalItems: Sendable, Hashable, Codable {
    var version: Version

    var conditionalUniqueItems: ConditionalUniqueItems
    var conditionalRepeatingItems: ConditionalRepeatingItems

    enum Version: Sendable, Hashable, Codable, Comparable {
        case v1
        case v2
        case v3
        case v4
        case v5
        case v6
        case v7
        case v8
    }
}

// MARK: - FirstSegmentConditionalItemsParser

struct FirstSegmentConditionalItemsParser: ParserPrinter {
    var body: some ParserPrinter<Substring, FirstSegmentConditionalItems> {
        ParsePrint(.memberwise(FirstSegmentConditionalItems.init)) {
            ">"
            VersionParser()
            ConditionalUniqueItemsParser()
            ConditionalRepeatingItemsParser()
        }
    }

    struct VersionParser: ParserPrinter {
        var body: some ParserPrinter<Substring, FirstSegmentConditionalItems.Version> {
            OneOf {
                "1".map { FirstSegmentConditionalItems.Version.v1 }
                "2".map { FirstSegmentConditionalItems.Version.v2 }
                "3".map { FirstSegmentConditionalItems.Version.v3 }
                "4".map { FirstSegmentConditionalItems.Version.v4 }
                "5".map { FirstSegmentConditionalItems.Version.v5 }
                "6".map { FirstSegmentConditionalItems.Version.v6 }
                "7".map { FirstSegmentConditionalItems.Version.v7 }
                "8".map { FirstSegmentConditionalItems.Version.v8 }
            }
        }
    }
}

// MARK: - ConditionalRepeatingItems

// I hate this stupid name, but this is sorta-kinda-what the spec refers to it as.
// All fields are marked as optional, because different versions of the spec have different fields, and airlines
// frequently omit fields they don't care about.
struct ConditionalRepeatingItems: Sendable, Codable, Hashable {
    var airlineNumericCode: String?
    var documentNumber: String?

    var selecteeIndicator: String?
    var internationalDocumentVerification: String?

    var marketingCarrierDesignator: String?

    var frequentFlyerAirlineDesignator: String?
    var frequentFlyerNumber: String?

    var idAdIndicator: String?
    var freeBaggageAllowance: String?

    var fastTrack: String?

    var airlinePrivateData: String?

    init(
        airlineNumericCode: String? = nil,
        documentNumber: String? = nil,
        selecteeIndicator: String? = nil,
        internationalDocumentVerification: String? = nil,
        marketingCarrierDesignator: String? = nil,
        frequentFlyerAirlineDesignator: String? = nil,
        frequentFlyerNumber: String? = nil,
        idAdIndicator: String? = nil,
        freeBaggageAllowance: String? = nil,
        fastTrack: String? = nil,
        airlinePrivateData: String? = nil,
    ) {
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

// MARK: - ConditionalUniqueItems

struct ConditionalUniqueItems: Sendable, Codable, Hashable {
    var passengerDescription: String
    var sourceOfCheckIn: String?
    var sourceOfIssuance: String?
    var dateOfIssuance: String?
    var documentType: String?
    var airlineDesignatorOfIssuer: String?

    var bags: [BaggageTag]?
}

// MARK: - ConditionalUniqueItemsParser

struct ConditionalUniqueItemsParser: ParserPrinter {
    var body: some ParserPrinter<Substring, ConditionalUniqueItems> {
        ParsePrint(.memberwise(ConditionalUniqueItems.init)) {
            HexLengthPrefixedParser {
                RightPaddedStringParser(length: 1) // passenger description

                Optionally {
                    RightPaddedStringParser(length: 1) // source of check-in
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // source of issuance
                }

                Optionally {
                    RightPaddedStringParser(length: 4) // date of issuance, julian date, year is a leading digit
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // document type
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // airline designator of issuer
                }

                Optionally {
                    BaggageTagParser()
                }
            }
        }
    }
}

// MARK: - ConditionalRepeatingItemsParser

struct ConditionalRepeatingItemsParser: ParserPrinter {
    var body: some ParserPrinter<Substring, ConditionalRepeatingItems> {
        ParsePrint(.memberwise(ConditionalRepeatingItems.init)) {
            HexLengthPrefixedParser {
                Optionally {
                    RightPaddedStringParser(length: 3) // airline numeric code
                }

                Optionally {
                    RightPaddedStringParser(length: 10) // document number
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // selectee indicator
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // international document verification
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // marketing carrier designator
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // frequent flyer airline designator
                }

                Optionally {
                    RightPaddedStringParser(length: 16) // frequent flyer number
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // ID/AD indicator
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // free baggage allowance
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // fast track
                }
            }

            Optionally {
                Rest().map(.string) // airline private data
            }
        }
    }
}

// MARK: - BaggageTag

enum BaggageTag: Sendable, Codable, Hashable {
    case emptyString
    case registeredBag(Int)
}

// MARK: - BaggageTagParser

struct BaggageTagParser: ParserPrinter {
    var body: some ParserPrinter<Substring, [BaggageTag]> {
        Parse {
            // I have a CX boarding pass with zero bags, that are encoded as 39 spaces.
            // Nobody else does it like that but heyo!
            Many(1 ... 3) {
                OneOf {
                    "             ".map { BaggageTag.emptyString }
                    Digits(13).map { .registeredBag(Int($0)) }
                }
                .printing { tag, input in
                    switch tag {
                    case .emptyString:
                        input.prepend(contentsOf: Array(repeating: " ", count: 13))
                    case let .registeredBag(number):
                        guard number >= 0 else {
                            throw BCBPError.bagNumberIsNegative
                        }

                        let numberString = String(format: "%013lu", number)

                        guard numberString.count == 13 else {
                            throw BCBPError.bagNumberTooBig
                        }

                        input.prepend(contentsOf: numberString)
                    }
                }
            }
        }
    }
}
