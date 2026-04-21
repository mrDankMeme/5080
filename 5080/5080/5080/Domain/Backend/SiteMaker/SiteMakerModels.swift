import Foundation

enum SiteMakerBuilderError: LocalizedError {
    case emptyPrompt
    case missingProject
    case missingClarifyResult
    case missingPreviewURL
    case invalidPreviewURL(String)
    case invalidUploadedAssetURL(String)
    case attachmentTooLarge(String)
    case backend(statusCode: Int, message: String)
    case stream(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt first."
        case .missingProject:
            return "Project is missing. Start with a prompt first."
        case .missingClarifyResult:
            return "Run clarify first, then generate the site."
        case .missingPreviewURL:
            return "Live site URL is missing. Generate the site first."
        case .invalidPreviewURL(let value):
            return "Live site URL is invalid: \(value)"
        case .invalidUploadedAssetURL(let value):
            return "Uploaded asset URL is invalid: \(value)"
        case .attachmentTooLarge(let value):
            return "\(value) is larger than 10 MB."
        case .backend(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .stream(let message):
            return message
        }
    }
}

struct SiteMakerAttachmentUploadPayload: Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
}

struct SiteMakerProjectSummary: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let status: String
    let previewURLString: String?
    let createdAt: String
    let updatedAt: String
}

struct SiteMakerCurrentUser: Sendable {
    let id: String
    let email: String
    let displayName: String?
    let credits: Int
    let createdAt: String
}

struct SiteMakerProject: Identifiable, Sendable {
    let id: String
    let userID: String
    let name: String
    let slug: String
    let description: String?
    let siteType: String
    let status: String
    let previewURLString: String?
    let currentSpec: String?
    let currentFiles: String?
    let createdAt: String
    let updatedAt: String
}

struct SiteMakerUploadedAsset: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let mimeType: String
    let fileSize: Int
    let createdAt: String
    let publicURLString: String?
}

struct SiteMakerClarifyQuestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let options: [String]
    let defaultIndex: Int
}

struct SiteMakerClarifyResult: Hashable, Sendable {
    let description: String
    let suggestedTheme: String
    let suggestedPalette: String
    let questions: [SiteMakerClarifyQuestion]
}

struct SiteMakerBuildOutcome: Hashable, Sendable {
    let previewURLString: String
    let outputPath: String
    let isSuccess: Bool
}

enum SiteMakerStreamStage: Sendable {
    case clarify
    case spec
    case code
    case build
}

enum SiteMakerStreamEvent: Sendable {
    case stageStarted(stage: SiteMakerStreamStage, message: String)
    case token(stage: SiteMakerStreamStage, message: String)
    case stageCompleted(stage: SiteMakerStreamStage, message: String)
    case clarifyCompleted(SiteMakerClarifyResult)
    case filesWritten(count: Int, durationMs: Int?)
    case buildCompleted(SiteMakerBuildOutcome)
    case message(name: String, value: String)
}
