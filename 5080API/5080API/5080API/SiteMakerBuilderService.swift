import Foundation

final class SiteMakerBuilderService {
    private let session: URLSession
    private let authService: SiteMakerAuthService
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
        self.authService = SiteMakerAuthService(session: session)
    }

    func createProject(
        baseURLString: String,
        authToken: String,
        prompt: String
    ) async throws -> SiteMakerProject {
        let payload = SiteMakerCreateProjectRequest(
            name: suggestedProjectName(from: prompt),
            description: prompt.trimmed.nilIfEmpty
        )

        let response = try await authService.sendRequest(
            baseURLString: baseURLString,
            method: .post,
            path: "/api/projects",
            authToken: authToken,
            body: try authService.makeJSONBody(payload)
        )

        guard response.isSuccess else {
            throw backendError(from: response)
        }

        return try authService.decode(SiteMakerProject.self, from: response)
    }

    func streamClarify(
        baseURLString: String,
        authToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerSSEEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            authToken: authToken,
            path: "/api/projects/\(projectID)/clarify",
            body: try encoder.encode(SiteMakerPromptRequest(prompt: prompt)),
            onEvent: onEvent
        )
    }

    func streamGenerate(
        baseURLString: String,
        authToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerSSEEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            authToken: authToken,
            path: "/api/projects/\(projectID)/generate",
            body: try encoder.encode(SiteMakerPromptRequest(prompt: prompt)),
            onEvent: onEvent
        )
    }

    func streamEdit(
        baseURLString: String,
        authToken: String,
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerSSEEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            authToken: authToken,
            path: "/api/projects/\(projectID)/edit",
            body: try encoder.encode(SiteMakerEditRequest(instruction: instruction)),
            onEvent: onEvent
        )
    }

    func fetchProject(
        baseURLString: String,
        authToken: String,
        projectID: String
    ) async throws -> SiteMakerProject {
        let response = try await authService.sendRequest(
            baseURLString: baseURLString,
            method: .get,
            path: "/api/projects/\(projectID)",
            authToken: authToken
        )

        guard response.isSuccess else {
            throw backendError(from: response)
        }

        return try authService.decode(SiteMakerProject.self, from: response)
    }

    private func stream(
        baseURLString: String,
        authToken: String,
        path: String,
        body: Data,
        onEvent: @escaping @MainActor (SiteMakerSSEEvent) -> Void
    ) async throws {
        let url = try makeURL(baseURLString: baseURLString, path: path)

        var request = URLRequest(url: url)
        request.httpMethod = SiteMakerHTTPMethod.post.rawValue
        request.httpBody = body
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        BuilderConsoleLogger.logRequest(request)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw SiteMakerServiceError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiteMakerServiceError.invalidHTTPResponse
        }

        guard httpResponse.statusCode == 200 else {
            let data = try await collectData(from: bytes)
            BuilderConsoleLogger.logResponse(httpResponse, data: data)
            let rawResponse = SiteMakerRawResponse(
                method: .post,
                url: url,
                statusCode: httpResponse.statusCode,
                data: data
            )
            throw backendError(from: rawResponse)
        }

        BuilderConsoleLogger.logStreamStart(response: httpResponse)

        var currentEvent = ""

        do {
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                    continue
                }

                if line.hasPrefix("data: ") {
                    let rawData = String(line.dropFirst(6))
                    let event = SiteMakerSSEEvent(event: currentEvent, data: rawData)

                    BuilderConsoleLogger.logEvent(event)
                    onEvent(event)

                    if currentEvent == "error" {
                        let message = decodeStreamErrorMessage(from: rawData)
                        throw BuilderFlowError.stream(message: message)
                    }
                }
            }
        } catch let error as BuilderFlowError {
            throw error
        } catch {
            throw SiteMakerServiceError.transport(error)
        }
    }

    private func makeURL(baseURLString: String, path: String) throws -> URL {
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

        guard let url = components.url else {
            throw SiteMakerServiceError.invalidEndpointURL
        }

        return url
    }

    private func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private func decodeStreamErrorMessage(from rawData: String) -> String {
        guard
            let data = rawData.data(using: .utf8),
            let errorEvent = try? JSONDecoder().decode(SiteMakerStreamErrorEvent.self, from: data)
        else {
            return rawData
        }

        return errorEvent.message
    }

    private func backendError(from response: SiteMakerRawResponse) -> BuilderFlowError {
        let message = authService.errorMessage(from: response) ?? "Unknown backend error."
        return .backend(statusCode: response.statusCode, message: message)
    }

    private func suggestedProjectName(from prompt: String) -> String {
        let normalized = prompt
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmed

        guard !normalized.isEmpty else {
            return "Untitled Site"
        }

        return String(normalized.prefix(48))
    }
}

private enum BuilderConsoleLogger {
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

    static func logStreamStart(response: HTTPURLResponse) {
        #if DEBUG
        print("[5080API][Response] \(response.statusCode) \(response.url?.absoluteString ?? "-")")
        print("[5080API][Response] body: <streaming text/event-stream>")
        #endif
    }

    static func logEvent(_ event: SiteMakerSSEEvent) {
        #if DEBUG
        let rendered = decodedString(from: event.data) ?? payloadSummary(data: event.data.data(using: .utf8)) ?? event.data
        let compact = rendered.replacingOccurrences(of: "\n", with: " ")
        let preview = compact.count > 140 ? "\(compact.prefix(140))..." : compact
        print("[5080API][SSE] \(event.event): \(preview)")
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

    private static func decodedString(from rawJSON: String) -> String? {
        guard let data = rawJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }
}
