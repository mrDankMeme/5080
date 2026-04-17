import Foundation

enum GenerationStatusError: LocalizedError {
    case apiError(String)
    case noData
    case generationFailed(String)
    case notCompleted(status: String)
    case noResultUrl
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .apiError(let message): return message
        case .noData: return "No data in response"
        case .generationFailed(let code): return "Generation failed: \(code)"
        case .notCompleted(let status): return "Generation not completed, status: \(status)"
        case .noResultUrl: return "No result URL"
        case .invalidImageData: return "Invalid image data"
        }
    }
}

struct GenerationStatusResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: GenerationStatusData?
}

struct GenerationStatusData: Decodable {
    let id: Int?
    let generationId: Int?
    let jobId: String?
    let preview: String?
    let resultUrl: String?
    let isVideo: Bool
    let status: String
    let errorCode: String?
}

struct GenerationResultPayload {
    let isVideo: Bool
    let resultData: Data
    let previewData: Data?
}

struct GenerateEffectResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: GenerateEffectData?
}

struct GenerateEffectData: Decodable {
    let jobId: String?
}

struct GenerateFrameResponse: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: GenerateFrameData?
}

struct GenerateFrameData: Decodable {
    let id: Int?
    let generationId: Int?
    let jobId: String?
    let status: String?
}
