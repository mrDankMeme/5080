import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case transport(Error)
    case emptyResponse
    case server(statusCode: Int, data: Data?)
    case decoding(Error)
    case backendMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .transport(let error):
            return error.localizedDescription
        case .emptyResponse:
            return "Empty response"
        case .server(let statusCode, let data):
            if let message = Self.extractServerMessage(from: data) {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .backendMessage(let message):
            return message
        }
    }
}

private extension APIError {
    static func extractServerMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = jsonObject["message"] as? String,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            if let code = jsonObject["code"] as? String,
               !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return code
            }
        }

        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(300))
            }
        }

        return nil
    }
}
