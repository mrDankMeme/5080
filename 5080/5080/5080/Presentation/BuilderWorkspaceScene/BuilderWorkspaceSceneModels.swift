import Foundation

enum BuilderPane: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case preview = "Live"

    var id: String { rawValue }
}

struct BuilderQuestionItem: Identifiable {
    let id: String
    let title: String
    let options: [String]
    var selectedIndex: Int
}

struct BuilderUploadedAssetItem: Identifiable, Hashable {
    let id: String
    let fileName: String
    let url: URL
    let mimeType: String
}

struct BuilderShareSheetPayload: Identifiable {
    let id = UUID()
    let items: [Any]
}
