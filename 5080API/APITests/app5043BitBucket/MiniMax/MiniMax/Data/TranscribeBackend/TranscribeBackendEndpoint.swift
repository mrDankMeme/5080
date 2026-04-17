import Foundation

enum TranscribeBackendEndpoint: Sendable {
    case transcribing
    case status(taskID: String)
    case result(taskID: String)

    var path: String {
        switch self {
        case .transcribing:
            return "task/transcribing"
        case let .status(taskID):
            return "task/status/\(taskID)"
        case let .result(taskID):
            return "task/result/\(taskID)"
        }
    }

    func url(baseURL: URL) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
