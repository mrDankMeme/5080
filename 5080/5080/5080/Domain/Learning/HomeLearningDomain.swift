import Foundation

enum CEFRLevel: String, CaseIterable, Codable, Hashable, Identifiable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    var id: String { rawValue }

    var order: Int {
        switch self {
        case .a1: return 0
        case .a2: return 1
        case .b1: return 2
        case .b2: return 3
        case .c1: return 4
        case .c2: return 5
        }
    }

    var title: String {
        switch self {
        case .a1: return "Beginner"
        case .a2: return "Elementary"
        case .b1: return "Intermediate"
        case .b2: return "Upper-Intermediate"
        case .c1: return "Advanced"
        case .c2: return "Proficient"
        }
    }

    var description: String {
        switch self {
        case .a1: return "Basic words, sounds, simple phrases"
        case .a2: return "Daily life, shopping, routine conversations"
        case .b1: return "Confident speaking and understanding"
        case .b2: return "Opinions, discussions, fluency"
        case .c1: return "Work, study, complex topics"
        case .c2: return "Near-native language mastery"
        }
    }

    var lessonCountHint: Int {
        switch self {
        case .a1: return 112
        case .a2: return 78
        case .b1: return 94
        case .b2: return 120
        case .c1: return 86
        case .c2: return 64
        }
    }

    var tintHex: String {
        switch self {
        case .a1: return "DCE5CD"
        case .a2: return "CDE2C9"
        case .b1: return "CBE3E7"
        case .b2: return "CBD8ED"
        case .c1: return "E7D8D1"
        case .c2: return "E4D5EC"
        }
    }

    var next: CEFRLevel? {
        CEFRLevel.allCases.first { $0.order == order + 1 }
    }

    var sectionTitle: String {
        "\(rawValue) - \(title)"
    }
}

struct LearningLanguage: Identifiable, Hashable {
    let id: String
    let code: String
    let title: String
    let badgeText: String
    let tintHex: String
    var levels: [LearningLevel]
}

struct LearningLevel: Identifiable, Hashable {
    let id: String
    let level: CEFRLevel
    let title: String
    let description: String
    var lessonCount: Int
    var lessons: [LearningLesson]
}

struct LearningLesson: Identifiable, Hashable {
    let id: String
    let order: Int
    var title: String
    var subtitle: String
    var contentManifest: LessonContentManifest?
}

struct LessonContentManifest: Codable, Hashable {
    let sourceSpreadsheet: String?
    let sourceLanguageCode: String?
    let sourceLevel: String?
    let sourceLessonNumber: Int?
    let audioBasename: String?
    let markdown: String?
    let quizPairs: [LessonQuizPair]
}

struct LessonQuizPair: Codable, Hashable {
    let question: String
    let answer: String
}

protocol LearningCatalogRepository {
    func fetchLanguages() -> [LearningLanguage]
}

protocol LearningProgressRepository {
    func loadSnapshot() -> LearningProgressSnapshot
    func saveSnapshot(_ snapshot: LearningProgressSnapshot)
}

struct LearningProgressSnapshot: Codable {
    var languageStates: [String: LearningLanguageProgressState]
    var savedLessonIDs: [String]
    var lastOpenedLesson: LearningLastOpenedLesson?

    static let empty = LearningProgressSnapshot(
        languageStates: [:],
        savedLessonIDs: [],
        lastOpenedLesson: nil
    )
}

struct LearningLanguageProgressState: Codable {
    var selectedLevel: CEFRLevel?
    var lessonProgress: [String: Double]
}

struct LearningLastOpenedLesson: Codable, Hashable {
    let languageID: String
    let lessonID: String
}
