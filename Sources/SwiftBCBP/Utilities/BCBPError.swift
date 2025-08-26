enum BCBPError: Error {
    case hexValueTooBig

    case bagNumberIsNegative
    case bagNumberTooBig

    var localizedDescription: String {
        switch self {
        case .hexValueTooBig:
            "Hex value is too big to fit in two digits."
        case .bagNumberIsNegative:
            "Bag number cannot be negative."
        case .bagNumberTooBig:
            "Bag number is too large to fit in 13 digits."
        }
    }
}
