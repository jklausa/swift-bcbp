import Parsing

struct HexLengthPrefixedParser<Downstream: Parser>: Parser where Downstream.Input == Substring {
    typealias Output = Downstream.Output

    let downstream: Downstream

    init(
        @ParserBuilder<Substring> _ build: () -> Downstream
    ) {
        self.downstream = build()
    }

    func parse(_ input: inout Substring) throws -> Downstream.Output {
        let length = try TwoDigitHexStringToInt().parse(&input)

        var prefix = try Prefix(length).parse(&input)

        return try self.downstream.parse(&prefix)
    }
}

extension HexLengthPrefixedParser: ParserPrinter where Downstream: ParserPrinter {
    func print(_ output: Downstream.Output, into input: inout Input) throws {
        var buffer = Substring()

        try self.downstream.print(output, into: &buffer)
        input.prepend(contentsOf: buffer)

        try TwoDigitHexStringToInt().print(buffer.count, into: &input)
    }
}

// MARK: - TwoDigitHexStringToInt

struct TwoDigitHexStringToInt: ParserPrinter {
    var body: some ParserPrinter<Substring, Int> {
        Prefix(2)
            .pipe { Int.parser(radix: 16) }
            .printing { value, input in
                guard value >= 0 && value <= 0xFF else {
                    throw BCBPError.hexValueTooBig
                }
                input.prepend(contentsOf: String(format: "%02X", value))
            }
    }
}
