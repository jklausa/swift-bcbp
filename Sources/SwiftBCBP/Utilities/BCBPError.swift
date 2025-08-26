enum BCBPError: Error {
    case hexValueTooBig

    case bagNumberIsNegative
    case bagNumberTooBig

    var localizedDescription: String {
        switch self {
        case .hexValueTooBig:
            return "Hex value is too big to fit in two digits."
        case .bagNumberIsNegative:
            return "Bag number cannot be negative."
        case .bagNumberTooBig:
            return "Bag number is too large to fit in 13 digits."
        }
    }

}
