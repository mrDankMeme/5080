import Foundation

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func send<T: Decodable>(_ request: HTTPRequest, responseType: T.Type) async throws -> T {
        let data = try await sendData(request)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func sendData(_ request: HTTPRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        NetworkConsoleLogger.logRequest(urlRequest)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            NetworkConsoleLogger.logTransportError(error, request: urlRequest)
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            NetworkConsoleLogger.logInvalidResponse(response, request: urlRequest)
            throw APIError.emptyResponse
        }

        NetworkConsoleLogger.logResponse(httpResponse, data: data)

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}

private enum NetworkConsoleLogger {
    private static let separator = "--------------------------------------------------"

    static func logRequest(_ request: URLRequest) {
#if DEBUG
        let method = request.httpMethod ?? "?"
        let urlString = request.url?.absoluteString ?? "nil"
        let headers = sanitizeHeaders(request.allHTTPHeaderFields ?? [:])
        let bodySummary = summarizeBody(data: request.httpBody, contentType: request.value(forHTTPHeaderField: "Content-Type"))

        print("\n\(separator)")
        print("[Network][Request] \(method) \(urlString)")
        if !headers.isEmpty {
            print("[Network][Request] headers: \(headers)")
        }
        if let bodySummary, !bodySummary.isEmpty {
            print("[Network][Request] body: \(bodySummary)")
        } else {
            print("[Network][Request] body: <empty>")
        }
#endif
    }

    static func logResponse(_ response: HTTPURLResponse, data: Data) {
#if DEBUG
        let urlString = response.url?.absoluteString ?? "nil"
        let statusCode = response.statusCode
        let contentType = response.value(forHTTPHeaderField: "Content-Type")
        let bodySummary = summarizeResponse(data: data, contentType: contentType)

        print("[Network][Response] \(statusCode) \(urlString)")
        print("[Network][Response] body: \(bodySummary)")
        print("\(separator)\n")
#endif
    }

    static func logTransportError(_ error: Error, request: URLRequest) {
#if DEBUG
        let method = request.httpMethod ?? "?"
        let urlString = request.url?.absoluteString ?? "nil"
        print("\n\(separator)")
        print("[Network][TransportError] \(method) \(urlString)")
        print("[Network][TransportError] \(error.localizedDescription)")
        print("\(separator)\n")
#endif
    }

    static func logInvalidResponse(_ response: URLResponse, request: URLRequest) {
#if DEBUG
        let method = request.httpMethod ?? "?"
        let urlString = request.url?.absoluteString ?? "nil"
        print("\n\(separator)")
        print("[Network][InvalidResponse] \(method) \(urlString)")
        print("[Network][InvalidResponse] type=\(type(of: response))")
        print("\(separator)\n")
#endif
    }

    private static func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var result = headers
        if let authKey = result.keys.first(where: { $0.caseInsensitiveCompare("Authorization") == .orderedSame }) {
            let value = result[authKey] ?? ""
            if value.count > 20 {
                let prefix = value.prefix(12)
                let suffix = value.suffix(4)
                result[authKey] = "\(prefix)...\(suffix)"
            } else {
                result[authKey] = "***"
            }
        }
        return result
    }

    private static func summarizeBody(data: Data?, contentType: String?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return summarizePayload(data: data, contentType: contentType)
    }

    private static func summarizeResponse(data: Data, contentType: String?) -> String {
        guard !data.isEmpty else { return "<empty>" }
        return summarizePayload(data: data, contentType: contentType)
    }

    private static func summarizePayload(data: Data, contentType: String?) -> String {
        let contentTypeValue = (contentType ?? "").lowercased()

        if contentTypeValue.contains("multipart/form-data") {
            return "<multipart/form-data \(data.count) bytes>"
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(jsonObject),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        if let stringValue = String(data: data, encoding: .utf8),
           !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stringValue
        }

        if !contentTypeValue.isEmpty {
            return "<binary payload \(data.count) bytes, content-type=\(contentTypeValue)>"
        }

        return "<binary payload \(data.count) bytes>"
    }
}
