import Foundation

struct BuilderQuestion: Identifiable {
    let id: String
    let title: String
    let options: [String]
    var selectedIndex: Int
}

struct SiteMakerCreateProjectRequest: Encodable {
    let name: String
    let description: String?
}

struct SiteMakerProject: Decodable {
    let id: String
    let user_id: String
    let name: String
    let slug: String
    let description: String?
    let site_type: String
    let status: String
    let preview_url: String?
    let current_spec: String?
    let current_files: String?
    let created_at: String
    let updated_at: String
}

struct SiteMakerPromptRequest: Encodable {
    let prompt: String
}

struct SiteMakerEditRequest: Encodable {
    let instruction: String
}

struct SiteMakerClarifyResponse: Decodable {
    let description: String
    let suggested_theme: String
    let suggested_palette: String
    let questions: [SiteMakerClarifyQuestion]
}

struct SiteMakerClarifyQuestion: Decodable {
    let id: String
    let question: String
    let options: [String]
    let `default`: Int
}

struct SiteMakerBuildResult: Decodable {
    let success: Bool
    let output_path: String
}

struct SiteMakerBuildComplete: Decodable {
    let preview_url: String
    let build: SiteMakerBuildResult
}

struct SiteMakerFilesWritten: Decodable {
    let file_count: Int?
    let files: [String]?
    let changed_files: [String]?
    let duration_ms: Int?
}

struct SiteMakerStreamErrorEvent: Decodable {
    let message: String
}

struct SiteMakerSSEEvent {
    let event: String
    let data: String
}

enum BuilderFlowError: LocalizedError {
    case emptyPrompt
    case missingAccessToken
    case missingClarifyResult
    case missingProject
    case missingPreviewURL
    case missingCurrentFiles
    case invalidPreviewURL(String)
    case backend(statusCode: Int, message: String)
    case stream(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt first."
        case .missingAccessToken:
            return "Access token is empty. Register or login on the Auth tab first."
        case .missingClarifyResult:
            return "Run clarify first, then generate the site."
        case .missingProject:
            return "Project is missing. Start with a prompt first."
        case .missingPreviewURL:
            return "Preview URL is missing. Generate the site first."
        case .missingCurrentFiles:
            return "Source files are not available yet. Generate the site first."
        case .invalidPreviewURL(let value):
            return "Preview URL is invalid: \(value)"
        case .backend(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .stream(let message):
            return message
        }
    }
}

struct BuilderShareSheetPayload: Identifiable {
    let id = UUID()
    let items: [Any]
    let subject: String?
}
