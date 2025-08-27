import Parsing

// MARK: - RawBoardingPass

struct RawBoardingPass: Sendable, Codable, Hashable {
    var formatCode: String
    var legsCount: Int

    var name: Name
    var isEticket: String

    var firstFlightSegment: FlightSegment
    var conditionalData: FirstSegmentConditionalItems?

    var otherSegments: [OtherSegments]?

    var securityData: SecurityData?

    var rest: String?
    // Sometimes the BP contains extra data beyond what is supposed to be there according
    // to the specified field lengths.
    // We capture it here so we can round-trip the parsing perfectly if needed.

}

struct RawBoardingPassParser: ParserPrinter {
    var body: some ParserPrinter<Substring, RawBoardingPass> {
        ParsePrint(.memberwise(RawBoardingPass.init)) {
            Prefix(1).map(.string) // format code
            Digits(1) // legs count
            NameParser()
            Prefix(1).map(.string) // e-ticket indicator

            FlightSegmentParser() // first flight segment

            Optionally {
                OneOf {
                    HexLengthPrefixedParser {
                        FirstSegmentConditionalItemsParser()
                    }
                    Parse {
                        Skip { Prefix(2) }
                            .printing{
                                _,
                                output in output.prepend(contentsOf: "00")
                            }
                        FirstSegmentConditionalItemsParser()
                    }
                    // Some airlines apparently can't be bothered to calculate the length of the conditional items,
                    // and just fill that field with all 00, and still put the conditional items after that.
                    // This lets those BPs still parse.
                    // Some other just... miscalculate the length.
                    // In those cases, we just always print out 00 as the length, which is technically wrong,
                    // but at least lets us parse the BP.
                }
            }

            Optionally {
                // The publicly available spec says:
                // "The BCBP standard enables the encoding up to four flight legs in the same BCBP."
                // That would mean up to 3 additional segments after the first one.
                Many(1...3) {
                    Parse(.memberwise(OtherSegments.init)) {
                        FlightSegmentParser()
                        HexLengthPrefixedParser {
                            Optionally {
                                ConditionalRepeatingItemsParser()
                            }
                        }
                    }
                }
            }

            Optionally {
                SecurityDataParser()
            }
            
            Optionally {
                Rest().map(.string)
            }
        }
    }
}

struct OtherSegments: Codable, Hashable, Sendable {
    var segment: FlightSegment
    var repeatingItems: ConditionalRepeatingItems?
}

struct FlightSegment: Codable, Hashable, Sendable {
    var PNR: String
    var originAirportCode: String
    var destinationAirportCode: String

    var carrierCode: String
    var flightNumber: String

    var julianFlightDate: Int

    var cabinClass: String

    var seat: String
    var sequenceNumber: String
    // should we try to turn it into a digit?

    var passengerStatus: String
}

struct FlightSegmentParser: ParserPrinter {
    var body: some ParserPrinter<Substring, FlightSegment> {
        ParsePrint(.memberwise(FlightSegment.init)) {
            RightPaddedStringParser(length: 7)
                .map(.string) // PNR

            RightPaddedStringParser(length: 3)
                .map(.string) // origin
            RightPaddedStringParser(length: 3)
                .map(.string) // destination

            RightPaddedStringParser(length: 3)
                .map(.string) // carrier

            RightPaddedStringParser(length: 5)
                .map(.string) // flight number

            Digits(3) // julian date

            OneOf {
                // Some of my Qatar Airways boarding passes have a cabin class field that just spells out the
                // whole cabin class, instead of using a single character, like the specs say.
                "BUSINESS".map { "Business" }
                "FIRST".map { "First" }
                Prefix(1).map(.string)
            } // class

            RightPaddedStringParser(length: 4).map(.string) // seat

            Prefix(5).map(.string)

            Prefix(1).map(.string) // passenger status
        }
    }
}

public struct Name: Sendable, Codable, Hashable {
    var lastName: String
    var firstName: String?
}

public struct NameParser: ParserPrinter {
    public var body: some ParserPrinter<Substring, Name> {
        ParsePrint(.memberwise(Name.init)) {
            RightPaddedStringParser(length: 20)
                .pipe {
                    Parse {
                        Prefix(while: { $0 != "/" }).map(.string)
                        Optionally {
                            "/"
                            Rest().map(.string)
                        }
                    }
                }
        }
    }
}


// MARK: - SecurityData

public struct SecurityData: Codable, Sendable, Hashable {
    var type: String
    var data: String
}

// MARK: - SecurityDataParser

public struct SecurityDataParser: ParserPrinter {
    public var body: some ParserPrinter<Substring, SecurityData> {
        ParsePrint(.memberwise(SecurityData.init)) {
            "^"
            Prefix(1).map(.string)
            HexLengthPrefixedParser {
                Rest().map(.string)
            }
        }
    }
}

// MARK: - FirstSegmentConditionalItems

struct FirstSegmentConditionalItems: Sendable, Hashable, Codable {
    var version: Version

    var conditionalUniqueItems: ConditionalUniqueItems
    var conditionalRepeatingItems: ConditionalRepeatingItems?

    enum Version: Sendable, Hashable, Codable {
        case v1
        case v2
        case v3
        case v4
        case v5
        case v6
        case v7
        case v8
        case unknown(String)
    }
}

// MARK: - FirstSegmentConditionalItemsParser

struct FirstSegmentConditionalItemsParser: ParserPrinter {
    var body: some ParserPrinter<Substring, FirstSegmentConditionalItems> {
        ParsePrint(.memberwise(FirstSegmentConditionalItems.init)) {
            ">"
            VersionParser()
            ConditionalUniqueItemsParser()
            Optionally { ConditionalRepeatingItemsParser() }
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
                ParsePrint(.case(FirstSegmentConditionalItems.Version.unknown)) {
                    Prefix(1).map(.string)
                }
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
                RightPaddedStringParser(length: 1).map(.string) // passenger description

                Optionally {
                    RightPaddedStringParser(length: 1).map(.string) // source of check-in
                }

                Optionally {
                    RightPaddedStringParser(length: 1).map(.string) // source of issuance
                }

                Optionally {
                    RightPaddedStringParser(length: 4).map(.string) // date of issuance, julian date, year is a leading digit
                }

                Optionally {
                    RightPaddedStringParser(length: 1).map(.string) // document type
                }

                Optionally {
                    RightPaddedStringParser(length: 3).map(.string) // airline designator of issuer
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
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 10) // document number
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // selectee indicator
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // international document verification
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // marketing carrier designator
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // frequent flyer airline designator
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 16) // frequent flyer number
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // ID/AD indicator
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 3) // free baggage allowance
                        .map(.string)
                }

                Optionally {
                    RightPaddedStringParser(length: 1) // fast track
                        .map(.string)
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
                    ParsePrint(.case(BaggageTag.registeredBag)) {
                        Digits(13)
                    }
                }
            }
        }
    }
}
