enum AspectRatio: CaseIterable, Identifiable {
    case aspectRatio4x3
    case aspectRatio3x2
    case aspectRatio16x9
    case aspectRatio1x1
    case aspectRatio4x5
    case aspectRatio2x3
    case aspectRatio9x16

    var id: Self { self }

    var description: String {
        switch self {
        case .aspectRatio4x3: return "4:3"
        case .aspectRatio3x2: return "3:2"
        case .aspectRatio16x9: return "16:9"
        case .aspectRatio1x1: return "1:1"
        case .aspectRatio4x5: return "4:5"
        case .aspectRatio2x3: return "2:3"
        case .aspectRatio9x16: return "9:16"
        }
    }

    var icon: String {
        switch self {
        case .aspectRatio4x3: return "rectangle"
        case .aspectRatio3x2: return "rectangle"
        case .aspectRatio16x9: return "rectangle"
        case .aspectRatio1x1: return "square"
        case .aspectRatio4x5: return "square"
        case .aspectRatio2x3: return "rectangle.portrait"
        case .aspectRatio9x16: return "rectangle.portrait"
        }
    }
}
