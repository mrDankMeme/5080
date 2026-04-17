import Foundation

enum BuilderSceneLaunch {
    case new(prompt: String, attachments: [BuilderAttachmentDraft])
    case existing(project: SiteMakerProjectSummary)
}

struct BuilderPresentationContext: Identifiable {
    let id = UUID()
    let launch: BuilderSceneLaunch
}
