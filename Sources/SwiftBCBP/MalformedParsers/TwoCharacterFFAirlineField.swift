import Parsing

// This is a parser for cases where a boarding pass has a two-character frequent flyer airline designator
// instead of the expected three-character designator.
struct TwoCharacterFFAirlineField: ParserPrinter {
    var body: some ParserPrinter<Substring, ConditionalRepeatingItems> {
        Parse {
            // Check for the malformed pattern
            Peek {
                // Check for pattern at position 20 (hex + 18 chars)
                Prefix(2) // Hex length
                Prefix(18) // Skip to FF airline position
                Prefix(2).filter { $0.allSatisfy { $0.isLetter && $0.isUppercase } } // 2 uppercase letters
                Prefix(1).filter { $0.first?.isNumber ?? false } // Followed by digit
            }

            // Parse with conversion to handle malformed data
            ParsePrint(TwoCharacterFFAirlineFieldConversion()) {
                // Parse the hex length
                Prefix(2).map(.string)

                // We know that at least this many fields need to be present for there to be the malformed FF airline
                // after.
                RightPaddedStringParser(length: 3).map(.string) // airline numeric code
                RightPaddedStringParser(length: 10).map(.string) // document number
                RightPaddedStringParser(length: 1).map(.string) // selectee indicator
                RightPaddedStringParser(length: 1).map(.string) // international document verification
                RightPaddedStringParser(length: 3).map(.string) // marketing carrier designator

                Prefix(2) // this is the malformed FF airline designator, should be 3 chars if aligned with the spec
                    .filter { $0.allSatisfy(\.isLetter) }
                    .map(.string)

                RightPaddedStringParser(length: 16).map(.string)

                Optionally {
                    // ID/AD indicator
                    RightPaddedStringParser(length: 1).map(.string)
                }

                Optionally {
                    // Free baggage allowance
                    RightPaddedStringParser(length: 3).map(.string)
                }

                Optionally {
                    // Fast track
                    RightPaddedStringParser(length: 1).map(.string)
                }

                Optionally {
                    Rest().map(.string) // airline private data
                }
            }
        }
    }
}

private struct TwoCharacterFFAirlineFieldConversion: Conversion {
    // swiftlint:disable:next large_tuple
    typealias Input = (String, String, String, String, String, String, String, String, String?, String?, String?, String?)
    typealias Output = ConditionalRepeatingItems

    func apply(_ input: Input) throws -> ConditionalRepeatingItems {
        // input.0 is the hex length, which we don't need here.
        ConditionalRepeatingItems(
            airlineNumericCode: input.1,
            documentNumber: input.2,
            selecteeIndicator: input.3,
            internationalDocumentVerification: input.4,
            marketingCarrierDesignator: input.5,
            frequentFlyerAirlineDesignator: input.6,
            frequentFlyerNumber: input.7,
            idAdIndicator: input.8,
            freeBaggageAllowance: input.9,
            fastTrack: input.10,
            airlinePrivateData: input.11,
        )
    }

    func unapply(_ output: ConditionalRepeatingItems) throws -> Input {
        var length = 3 + 10 + 1 + 1 + 3 + 2 + 16
        // We know that there are at least this many fields present for the parsing to succeed.

        if output.fastTrack != nil {
            length += 1
        }

        if output.freeBaggageAllowance != nil {
            length += 3
        }

        if output.idAdIndicator != nil {
            length += 1
        }

        if let privateData = output.airlinePrivateData {
            length += privateData.count
        }

        let hexLength = String(format: "%02X", length)

        return (
            hexLength,
            output.airlineNumericCode ?? "",
            output.documentNumber ?? "",
            output.selecteeIndicator ?? "",
            output.internationalDocumentVerification ?? "",
            output.marketingCarrierDesignator ?? "",
            output.frequentFlyerAirlineDesignator ?? "",
            output.frequentFlyerNumber ?? "",
            output.idAdIndicator,
            output.freeBaggageAllowance,
            output.fastTrack,
            output.airlinePrivateData,
        )
    }
}

// MARK: - Convenience extension

extension Malformed {
    static var twoCharacterFFAirlineField: some ParserPrinter<Substring, ConditionalRepeatingItems> {
        TwoCharacterFFAirlineField()
    }
}
