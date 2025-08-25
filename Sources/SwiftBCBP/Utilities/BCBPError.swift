enum BCBPError: Error {
    case hexValueTooBig

    var localizedDescription: String {
        switch self {
        case .hexValueTooBig:
            return "Hex value is too big to fit in two digits."
        }
    }

}
