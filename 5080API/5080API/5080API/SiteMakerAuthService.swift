import Foundation

enum SiteMakerRequestBody {
    case none
    case json(Data)
}

enum SiteMakerServiceError: LocalizedError {
    case invalidBaseURL(String)
    case invalidEndpointURL
    case invalidHTTPResponse
    case encoding(Error)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid base URL: \(value)"
        case .invalidEndpointURL:
            return "Failed to build endpoint URL."
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .encoding(let error), .decoding(let error), .transport(let error):
            return error.localizedDescription
        }
    }
}

final class SiteMakerAuthService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func makeJSONBody<T: Encodable>(_ payload: T) throws -> SiteMakerRequestBody {
        do {
            return .json(try encoder.encode(payload))
        } catch {
            throw SiteMakerServiceError.encoding(error)
        }
    }

    func sendRequest(
        baseURLString: String,
        method: SiteMakerHTTPMethod,
        path: String,
        authToken: String? = nil,
        queryItems: [URLQueryItem] = [],
        body: SiteMakerRequestBody = .none
    ) async throws -> SiteMakerRawResponse {
        let url = try makeURL(baseURLString: baseURLString, path: path, queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authToken, !authToken.trimmed.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        switch body {
        case .none:
            break
        case .json(let payload):
            request.httpBody = payload
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        NetworkConsoleLogger.logRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SiteMakerServiceError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiteMakerServiceError.invalidHTTPResponse
        }

        NetworkConsoleLogger.logResponse(httpResponse, data: data)

        return SiteMakerRawResponse(
            method: method,
            url: url,
            statusCode: httpResponse.statusCode,
            data: data
        )
    }

    func decode<T: Decodable>(_ type: T.Type, from response: SiteMakerRawResponse) throws -> T {
        do {
            return try decoder.decode(type, from: response.data)
        } catch {
            throw SiteMakerServiceError.decoding(error)
        }
    }

    func errorMessage(from response: SiteMakerRawResponse) -> String? {
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: response.data) {
            return apiError.detail
        }

        let trimmedBody = plainText(from: response.data).trimmed
        return trimmedBody.isEmpty ? nil : trimmedBody
    }

    func responseText(from response: SiteMakerRawResponse) -> String {
        let header = "\(response.method.rawValue) \(response.url.absoluteString)\nHTTP \(response.statusCode)"
        let body = prettyPayload(from: response.data)
        return "\(header)\n\n\(body)"
    }

    private func makeURL(baseURLString: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURLString) else {
            throw SiteMakerServiceError.invalidBaseURL(baseURLString)
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if basePath.isEmpty {
            components.path = "/" + trimmedPath
        } else if trimmedPath.isEmpty {
            components.path = "/" + basePath
        } else {
            components.path = "/" + basePath + "/" + trimmedPath
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw SiteMakerServiceError.invalidEndpointURL
        }

        return url
    }

    private func prettyPayload(from data: Data) -> String {
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        let plain = plainText(from: data)
        return plain.trimmed.isEmpty ? "<empty>" : plain
    }

    private func plainText(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "<binary payload \(data.count) bytes>"
    }
}

private enum NetworkConsoleLogger {
    private static let separator = "--------------------------------------------------"

    static func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "-"
        let headers = sanitizedHeaders(request.allHTTPHeaderFields ?? [:])
        let body = payloadSummary(data: request.httpBody) ?? "<empty>"

        print("\n\(separator)")
        print("[5080API][Request] \(method) \(url)")
        if !headers.isEmpty {
            print("[5080API][Request] headers: \(headers)")
        }
        print("[5080API][Request] body: \(body)")
        #endif
    }

    static func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        print("[5080API][Response] \(response.statusCode) \(response.url?.absoluteString ?? "-")")
        print("[5080API][Response] body: \(payloadSummary(data: data) ?? "<empty>")")
        print("\(separator)\n")
        #endif
    }

    private static func sanitizedHeaders(_ headers: [String: String]) -> [String: String] {
        var result = headers

        if let authKey = result.keys.first(where: { $0.caseInsensitiveCompare("Authorization") == .orderedSame }) {
            let value = result[authKey] ?? ""
            if value.count > 20 {
                result[authKey] = "\(value.prefix(12))...\(value.suffix(4))"
            } else {
                result[authKey] = "***"
            }
        }

        return result
    }

    private static func payloadSummary(data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return String(data: data, encoding: .utf8) ?? "<binary payload \(data.count) bytes>"
    }
}
