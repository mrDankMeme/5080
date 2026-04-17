import Foundation

struct EffectsListResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: EffectsListData?
}

struct EffectsListData: Decodable {
    let list: [TemplateItem]
    let totalTemplates: Int
    let totalUsed: Int
}

struct TemplateItem: Decodable, Identifiable, Hashable {
    static func == (lhs: TemplateItem, rhs: TemplateItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: Int
    let title: String?
    let description: String?
    let preview: String?
    let isNew: Bool
    let totalEffects: Int
    let totalUsed: Int
    let effects: [EffectItem]
}

struct EffectItem: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let preview: String?
    let previewProduction: String?
    let previewBefore: String?
    let gender: String?
    let prompt: String?
    let isEnabled: Bool
}

struct EffectWithTemplate: Identifiable, Hashable {
    let effect: EffectItem
    let template: TemplateItem

    var id: Int { effect.id }

    static func == (lhs: EffectWithTemplate, rhs: EffectWithTemplate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
