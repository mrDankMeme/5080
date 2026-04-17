import Foundation

struct PhotoStylesResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: [PhotoStyleItem]?
}

struct PhotoStyleItem: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let description: String?
    let preview: String?
    let totalTemplates: Int?
    let totalUsed: Int?
    let templates: [PhotoStyleTemplateItem]
}

struct PhotoStyleTemplateItem: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let styleId: Int?
    let preview: String?
    let previewProduction: String?
    let gender: String?
    let prompt: String?
    let isEnabled: Bool?
}

extension PhotoStyleItem {
    var preferredTemplateId: Int {
        templates.first(where: { $0.isEnabled != false })?.id
            ?? templates.first?.id
            ?? id
    }
}
