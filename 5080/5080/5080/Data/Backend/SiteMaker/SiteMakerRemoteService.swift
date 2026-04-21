import Foundation

protocol SiteMakerRemoteServicing {
    func fetchCurrentUser(
        baseURLString: String,
        accessToken: String
    ) async throws -> SiteMakerCurrentUser
    func listProjects(
        baseURLString: String,
        accessToken: String
    ) async throws -> [SiteMakerProjectSummary]
    func createProject(
        baseURLString: String,
        accessToken: String,
        prompt: String
    ) async throws -> SiteMakerProject
    func fetchProject(
        baseURLString: String,
        accessToken: String,
        projectID: String
    ) async throws -> SiteMakerProject
    func uploadAsset(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset
    func streamClarify(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
    func streamGenerate(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
    func streamEdit(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
}

final class SiteMakerRemoteService: SiteMakerRemoteServicing {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCurrentUser(
        baseURLString: String,
        accessToken: String
    ) async throws -> SiteMakerCurrentUser {
        let response = try await performRequest(
            baseURLString: baseURLString,
            method: "GET",
            path: "/api/auth/me",
            authToken: accessToken
        )

        guard (200..<300).contains(response.statusCode) else {
            throw backendError(from: response)
        }

        let currentUser = try decode(SiteMakerCurrentUserResponse.self, from: response.data).toDomain()
        SiteMakerDebugLogger.logAuth(
            "Loaded current user id=\(currentUser.id), credits=\(currentUser.credits), email=\(currentUser.email)"
        )
        return currentUser
    }

    func listProjects(
        baseURLString: String,
        accessToken: String
    ) async throws -> [SiteMakerProjectSummary] {
        let response = try await performRequest(
            baseURLString: baseURLString,
            method: "GET",
            path: "/api/projects",
            authToken: accessToken
        )

        guard (200..<300).contains(response.statusCode) else {
            throw backendError(from: response)
        }

        let items = try decode([SiteMakerProjectSummaryResponse].self, from: response.data)
        return items
            .map { $0.toDomain() }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func createProject(
        baseURLString: String,
        accessToken: String,
        prompt: String
    ) async throws -> SiteMakerProject {
        let payload = SiteMakerCreateProjectRequest(
            name: suggestedProjectName(from: prompt),
            description: prompt.trimmed.nilIfEmpty
        )

        let response = try await performRequest(
            baseURLString: baseURLString,
            method: "POST",
            path: "/api/projects",
            authToken: accessToken,
            jsonBody: try encode(payload)
        )

        guard (200..<300).contains(response.statusCode) else {
            throw backendError(from: response)
        }

        return try decode(SiteMakerProjectResponse.self, from: response.data).toDomain()
    }

    func fetchProject(
        baseURLString: String,
        accessToken: String,
        projectID: String
    ) async throws -> SiteMakerProject {
        let response = try await performRequest(
            baseURLString: baseURLString,
            method: "GET",
            path: "/api/projects/\(projectID)",
            authToken: accessToken
        )

        guard (200..<300).contains(response.statusCode) else {
            throw backendError(from: response)
        }

        return try decode(SiteMakerProjectResponse.self, from: response.data).toDomain()
    }

    func uploadAsset(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = MultipartFormDataBuilder(boundary: boundary).buildBody(
            fields: [:],
            files: [
                MultipartFormDataBuilder.File(
                    name: "file",
                    filename: payload.fileName,
                    mimeType: payload.mimeType,
                    data: payload.data
                )
            ]
        )

        let response = try await performRequest(
            baseURLString: baseURLString,
            method: "POST",
            path: "/api/projects/\(projectID)/upload",
            authToken: accessToken,
            additionalHeaders: [
                "Content-Type": "multipart/form-data; boundary=\(boundary)"
            ],
            rawBody: body
        )

        guard (200..<300).contains(response.statusCode) else {
            throw backendError(from: response)
        }

        let asset = try decode(SiteMakerUploadedAssetResponse.self, from: response.data)
        return asset.toDomain(
            baseURLString: baseURLString,
            projectSlug: projectSlug
        )
    }

    func streamClarify(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            accessToken: accessToken,
            path: "/api/projects/\(projectID)/clarify",
            body: try encode(SiteMakerPromptRequest(prompt: prompt)),
            expectedCompletionEventNames: ["clarify_complete", "clarify_completed"],
            onEvent: onEvent
        )
    }

    func streamGenerate(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            accessToken: accessToken,
            path: "/api/projects/\(projectID)/generate",
            body: try encode(SiteMakerPromptRequest(prompt: prompt)),
            expectedCompletionEventNames: ["build_complete", "build_completed"],
            onEvent: onEvent
        )
    }

    func streamEdit(
        baseURLString: String,
        accessToken: String,
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await stream(
            baseURLString: baseURLString,
            accessToken: accessToken,
            path: "/api/projects/\(projectID)/edit",
            body: try encode(SiteMakerEditRequest(instruction: instruction)),
            expectedCompletionEventNames: ["build_complete", "build_completed"],
            onEvent: onEvent
        )
    }
}

private extension SiteMakerRemoteService {
    typealias RawResponse = (statusCode: Int, data: Data)

    func stream(
        baseURLString: String,
        accessToken: String,
        path: String,
        body: Data,
        expectedCompletionEventNames: Set<String>,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        let url = try makeURL(baseURLString: baseURLString, path: path, queryItems: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let bytes: URLSession.AsyncBytes
        let response: URLResponse

        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiteMakerAuthorizationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let data = try await collectData(from: bytes)
            throw backendError(from: (httpResponse.statusCode, data))
        }

        var currentEventName = ""
        let normalizedCompletionEventNames = Set(
            expectedCompletionEventNames.map(normalizedEventName(from:))
        )
        var didReceiveExpectedCompletion = false
        var didReceiveAnyDataEvent = false

        do {
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEventName = String(line.dropFirst(7))
                    continue
                }

                if line.hasPrefix("data: ") {
                    let rawValue = String(line.dropFirst(6))
                    didReceiveAnyDataEvent = true
                    let normalizedEvent = normalizedEventName(from: currentEventName)

                    if normalizedCompletionEventNames.contains(normalizedEvent) {
                        didReceiveExpectedCompletion = true
                    }

                    if normalizedEvent == "error" {
                        throw SiteMakerBuilderError.stream(
                            message: decodeStreamError(from: rawValue)
                        )
                    }

                    if let event = mapStreamEvent(
                        name: currentEventName,
                        rawValue: rawValue
                    ) {
                        onEvent(event)
                    }
                }
            }

            if !didReceiveAnyDataEvent {
                throw SiteMakerBuilderError.stream(
                    message: "The generation stream returned no events."
                )
            }

            if !didReceiveExpectedCompletion {
                throw SiteMakerBuilderError.stream(
                    message: "The generation stream ended before a completion event arrived."
                )
            }
        } catch let error as SiteMakerBuilderError {
            throw error
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }
    }

    func mapStreamEvent(
        name: String,
        rawValue: String
    ) -> SiteMakerStreamEvent? {
        let renderedValue = decodeString(from: rawValue) ?? rawValue

        switch normalizedEventName(from: name) {
        case "clarify_start":
            return .stageStarted(stage: .clarify, message: renderedValue)
        case "clarify_token":
            return .token(stage: .clarify, message: renderedValue)
        case "clarify_complete", "clarify_completed":
            if let result = decode(SiteMakerClarifyResponse.self, from: rawValue) {
                return .clarifyCompleted(result.toDomain())
            }
            return .message(name: name, value: renderedValue)

        case "spec_start":
            return .stageStarted(stage: .spec, message: renderedValue)
        case "spec_token":
            return .token(stage: .spec, message: renderedValue)
        case "spec_complete":
            return .stageCompleted(stage: .spec, message: renderedValue)

        case "code_start":
            return .stageStarted(stage: .code, message: renderedValue)
        case "code_token":
            return .token(stage: .code, message: renderedValue)
        case "code_complete":
            return .stageCompleted(stage: .code, message: renderedValue)

        case "build_start":
            return .stageStarted(stage: .build, message: renderedValue)
        case "files_written":
            if let payload = decode(SiteMakerFilesWrittenResponse.self, from: rawValue) {
                let count = payload.file_count
                    ?? payload.files?.count
                    ?? payload.changed_files?.count
                    ?? 0
                return .filesWritten(count: count, durationMs: payload.duration_ms)
            }
            return .message(name: name, value: renderedValue)
        case "build_complete", "build_completed":
            if let payload = decode(SiteMakerBuildCompleteResponse.self, from: rawValue) {
                return .buildCompleted(payload.toDomain())
            }
            return .message(name: name, value: renderedValue)

        default:
            return .message(name: name, value: renderedValue)
        }
    }

    func performRequest(
        baseURLString: String,
        method: String,
        path: String,
        authToken: String? = nil,
        queryItems: [URLQueryItem] = [],
        additionalHeaders: [String: String] = [:],
        jsonBody: Data? = nil,
        rawBody: Data? = nil
    ) async throws -> RawResponse {
        let url = try makeURL(
            baseURLString: baseURLString,
            path: path,
            queryItems: queryItems
        )

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let authToken, !authToken.trimmed.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let jsonBody {
            request.httpBody = jsonBody
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        } else if let rawBody {
            request.httpBody = rawBody
        }

        SiteMakerDebugLogger.logRequest(request)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SiteMakerAuthorizationError.invalidResponse
        }

        SiteMakerDebugLogger.logResponse(
            url: request.url,
            statusCode: httpResponse.statusCode,
            data: data
        )

        return (httpResponse.statusCode, data)
    }

    func makeURL(
        baseURLString: String,
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        guard var components = URLComponents(string: baseURLString) else {
            throw SiteMakerAuthorizationError.invalidBaseURL
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        components.path = basePath.isEmpty
            ? "/" + trimmedPath
            : "/" + basePath + "/" + trimmedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SiteMakerAuthorizationError.invalidBaseURL
        }

        return url
    }

    func collectData(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw SiteMakerAuthorizationError.transport(error)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SiteMakerAuthorizationError.decoding(error)
        }
    }

    func decodeString(from rawValue: String) -> String? {
        guard let data = rawValue.data(using: .utf8) else {
            return nil
        }

        if let decoded = try? decoder.decode(String.self, from: data) {
            return decoded
        }

        return rawValue
    }

    func decode<T: Decodable>(_ type: T.Type, from rawValue: String) -> T? {
        guard let data = rawValue.data(using: .utf8) else {
            return nil
        }

        if let value = try? decoder.decode(type, from: data) {
            return value
        }

        guard
            let nestedJSONString = try? decoder.decode(String.self, from: data),
            let nestedData = nestedJSONString.data(using: .utf8)
        else {
            return nil
        }

        return try? decoder.decode(type, from: nestedData)
    }

    func decodeStreamError(from rawValue: String) -> String {
        decode(SiteMakerStreamErrorResponse.self, from: rawValue)?.message ?? rawValue
    }

    func backendError(from response: RawResponse) -> SiteMakerBuilderError {
        .backend(
            statusCode: response.statusCode,
            message: errorMessage(from: response.data) ?? "Unknown backend error."
        )
    }

    func errorMessage(from data: Data) -> String? {
        if let apiError = try? decoder.decode(SiteMakerAuthorizationErrorPayload.self, from: data) {
            return apiError.detail.nilIfEmpty
        }

        return String(data: data, encoding: .utf8)?.trimmed.nilIfEmpty
    }

    func suggestedProjectName(from prompt: String) -> String {
        let normalized = prompt
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmed

        guard !normalized.isEmpty else {
            return "Untitled Site"
        }

        return String(normalized.prefix(48))
    }

    func normalizedEventName(from name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct SiteMakerAuthorizationErrorPayload: Decodable {
    let detail: String
}
