import Foundation

struct MultipartUploadFile {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

struct BackendRawResponse {
    let method: BackendHTTPMethod
    let url: URL
    let statusCode: Int
    let data: Data

    var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

enum BackendTestServiceError: LocalizedError {
    case invalidBaseURL(String)
    case invalidEndpointURL
    case transport(Error)
    case invalidHTTPResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid base URL: \(value)"
        case .invalidEndpointURL:
            return "Failed to build endpoint URL"
        case .transport(let error):
            return error.localizedDescription
        case .invalidHTTPResponse:
            return "Invalid HTTP response"
        }
    }
}

final class BackendTestService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendRequest(
        baseURLString: String,
        bearerToken: String,
        method: BackendHTTPMethod,
        path: String,
        queryItems: [URLQueryItem],
        bodyType: EndpointBodyType,
        multipartFields: [String: [String]] = [:],
        files: [MultipartUploadFile] = []
    ) async throws -> BackendRawResponse {
        let endpointURL = try makeURL(baseURLString: baseURLString, path: path, queryItems: queryItems)

        var request = URLRequest(url: endpointURL)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch bodyType {
        case .none:
            if method == .post {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        case .multipartFormData:
            let builder = MultipartFormDataBuilder()
            request.httpBody = builder.buildBody(fields: multipartFields, files: files)
            request.setValue(builder.contentTypeHeaderValue(), forHTTPHeaderField: "Content-Type")
        }

        XcodeConsoleNetworkLogger.logRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BackendTestServiceError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendTestServiceError.invalidHTTPResponse
        }

        XcodeConsoleNetworkLogger.logResponse(httpResponse, data: data)

        return BackendRawResponse(
            method: method,
            url: endpointURL,
            statusCode: httpResponse.statusCode,
            data: data
        )
    }

    private func makeURL(baseURLString: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        let rawURL: URL
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            guard let absolute = URL(string: path) else {
                throw BackendTestServiceError.invalidEndpointURL
            }
            rawURL = absolute
        } else {
            guard let baseURL = URL(string: baseURLString) else {
                throw BackendTestServiceError.invalidBaseURL(baseURLString)
            }
            rawURL = baseURL.appendingPathComponent(path)
        }

        guard var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false) else {
            throw BackendTestServiceError.invalidEndpointURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let finalURL = components.url else {
            throw BackendTestServiceError.invalidEndpointURL
        }

        return finalURL
    }
}

private struct MultipartFormDataBuilder {
    let boundary: String

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    func contentTypeHeaderValue() -> String {
        "multipart/form-data; boundary=\(boundary)"
    }

    func buildBody(fields: [String: [String]], files: [MultipartUploadFile]) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (key, values) in fields {
            for value in values {
                body.append("--\(boundary)\(lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
                body.append("\(value)\(lineBreak)")
            }
        }

        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)")
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}

private enum XcodeConsoleNetworkLogger {
    private static let separator = "--------------------------------------------------"

    static func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "-"
        let headers = sanitizedHeaders(request.allHTTPHeaderFields ?? [:])
        let body = payloadSummary(data: request.httpBody, contentType: request.value(forHTTPHeaderField: "Content-Type"))

        print("\n\(separator)")
        print("[BackendLab][Request] \(method) \(url)")
        if !headers.isEmpty {
            print("[BackendLab][Request] headers: \(headers)")
        }
        if let body, !body.isEmpty {
            print("[BackendLab][Request] body: \(body)")
        } else {
            print("[BackendLab][Request] body: <empty>")
        }
        #endif
    }

    static func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let url = response.url?.absoluteString ?? "-"
        let status = response.statusCode
        let body = payloadSummary(data: data, contentType: response.value(forHTTPHeaderField: "Content-Type")) ?? "<empty>"
        print("[BackendLab][Response] \(status) \(url)")
        print("[BackendLab][Response] body: \(body)")
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

    private static func payloadSummary(data: Data?, contentType: String?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        let contentType = (contentType ?? "").lowercased()
        if contentType.contains("multipart/form-data") {
            return "<multipart/form-data \(data.count) bytes>"
        }

        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let pretty = String(data: prettyData, encoding: .utf8) {
            return pretty
        }

        if let utf8 = String(data: data, encoding: .utf8), !utf8.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return utf8
        }

        return "<binary payload \(data.count) bytes>"
    }
}
