import Foundation

enum TranscribeOutputFormat: String, Sendable, Codable {
    case fullText
    case summary
}

struct TranscribeSelectedMedia: Sendable {
    let data: Data
    let fileName: String
    let mimeType: String
    let isVideo: Bool
}

struct TranscribeTranscriptSegment: Sendable, Hashable, Codable {
    let text: String
    let start: Double
    let end: Double
}

struct TranscribeResultPayload: Sendable, Codable {
    let fileName: String
    let isVideo: Bool
    let outputFormat: TranscribeOutputFormat
    let timestampsEnabled: Bool
    let transcriptSegments: [TranscribeTranscriptSegment]
    let summaryTopics: [String]
    let rawResultJSONString: String
}
