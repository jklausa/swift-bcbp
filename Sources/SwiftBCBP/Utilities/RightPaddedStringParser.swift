import Parsing

struct RightPaddedStringParser: ParserPrinter {
    let length: Int

    var body: some Parser<Substring, String> {
        Prefix(length)
            .map { substring in
                var substring = substring

                while substring.last == " " {
                    substring.removeLast()
                }

                return String(substring)
            }
    }

    func print(_ output: String, into input: inout Substring) throws {
        let paddingCount = length - output.count

        for _ in 0 ..< paddingCount {
            input.prepend(" ")
        }

        input.prepend(contentsOf: output)
    }
}
