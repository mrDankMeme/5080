import Foundation

final class MiniMaxBackendServiceImpl: MiniMaxBackendService {
    private let config: APIConfig
    private let http: HTTPClient
    private let decoder: JSONDecoder
    private let source: String

    init(
        config: APIConfig,
        http: HTTPClient,
        source: String = MiniMaxBackendDefaults.source,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.config = config
        self.http = http
        self.source = source
        self.decoder = decoder
    }

    func authorize(userId: String, gender: String) async throws -> BackendAuthData {
        // Keep `source` aligned with the validated APIDog environment (5045) values.
        let resolvedSource = source
        let url = try makeURL(
            endpoint: .userLogin,
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "gender", value: gender),
                URLQueryItem(name: "source", value: resolvedSource),
                URLQueryItem(name: "isFb", value: "0"),
                URLQueryItem(name: "payments", value: "1")
            ]
        )

        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: authorizedHeaders()
        )

        let envelope: BackendEnvelope<BackendAuthData> = try await sendEnvelope(request, endpointName: "user/login")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Empty auth payload")
        }
        return data
    }

    func fetchProfile(userId: String) async throws -> BackendProfileData {
        // APIDog still shows chatId in schema, but backend team confirmed userId should be sent.
        let url = try makeURL(
            endpoint: .userProfile,
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )

        let request = HTTPRequest(
            url: url,
            method: .get,
            headers: authorizedHeaders()
        )

        let envelope: BackendEnvelope<BackendProfileData> = try await sendEnvelope(request, endpointName: "user/profile")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Empty profile payload")
        }
        return data
    }

    func setFreeGenerations(userId: String) async throws {
        let url = try makeURL(
            endpoint: .userSetFreeGenerations,
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "source", value: source)
            ]
        )

        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: authorizedHeaders()
        )

        let _: BackendEnvelope<BackendIgnoredPayload> = try await sendEnvelope(request, endpointName: "user/setFreeGenerations")
    }

    func addGenerations(userId: String, productId: Int) async throws {
        let url = try makeURL(
            endpoint: .userAddGenerations,
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "productId", value: String(productId)),
                URLQueryItem(name: "source", value: source)
            ]
        )

        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: authorizedHeaders()
        )

        let _: BackendEnvelope<BackendIgnoredPayload> = try await sendEnvelope(request, endpointName: "user/addGenerations")
    }

    func collectTokens(userId: String) async throws {
        let endpoint = try makeURL(endpoint: .userCollectTokens)
        let builder = MultipartFormDataBuilder()
        let body = builder.buildBody(fields: ["userId": userId], files: [])

        let request = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: authorizedHeaders(contentType: builder.contentTypeHeaderValue()),
            body: body
        )

        let _: BackendEnvelope<BackendIgnoredPayload> = try await sendEnvelope(request, endpointName: "user/collectTokens")
    }

    func fetchAvailableBonuses(userId: String) async throws -> [BackendAvailableBonusItem] {
        let url = try makeURL(
            endpoint: .userAvailableBonuses,
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )

        let request = HTTPRequest(
            url: url,
            method: .get,
            headers: authorizedHeaders()
        )

        let envelope: BackendEnvelope<[BackendAvailableBonusItem]> = try await sendEnvelope(request, endpointName: "user/availableBonuses")
        return envelope.data ?? []
    }

    func fetchServicePrices(userId: String) async throws -> BackendServicePricesData {
        let url = try makeURL(
            endpoint: .servicesPrices,
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        )

        let request = HTTPRequest(
            url: url,
            method: .get,
            headers: authorizedHeaders()
        )

        let envelope: BackendEnvelope<BackendServicePricesData> = try await sendEnvelope(request, endpointName: "services/prices")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Empty prices payload")
        }

        return data
    }

    func textToVideo(_ request: TextToVideoRequest) async throws -> BackendGenerationStartData {
        let endpoint = try makeURL(endpoint: .textToVideo)
        let builder = MultipartFormDataBuilder()

        var fields: [String: String] = [
            "userId": request.userId,
            "cfgScale": request.cfgScale,
            "duration": request.duration,
            "aspectRatio": request.aspectRatio,
            "prompt": request.prompt,
            "modelName": request.modelName,
            "mode": request.mode
        ]

        if let negativePrompt = request.negativePrompt,
           !negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["negativePrompt"] = negativePrompt
        }

        let body = builder.buildBody(fields: fields, files: [])
        let httpRequest = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: authorizedHeaders(contentType: builder.contentTypeHeaderValue()),
            body: body
        )

        let envelope: BackendEnvelope<BackendGenerationStartData> = try await sendEnvelope(httpRequest, endpointName: "video/generate/txt2video")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Generation start payload is empty")
        }
        return data
    }

    func animateImage(_ request: AnimateImageRequest) async throws -> BackendGenerationStartData {
        let endpoint = try makeURL(endpoint: .animateImage)
        let builder = MultipartFormDataBuilder()

        var fields: [String: String] = ["userId": request.userId]

        if let prompt = request.prompt,
           !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["prompt"] = prompt
        }

        if let photoURL = request.photoURL,
           !photoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["photoUrl"] = photoURL
        }

        let files = [
            MultipartFormDataBuilder.File(
                name: "file",
                filename: request.file.fileName,
                mimeType: request.file.mimeType,
                data: request.file.data
            )
        ]

        let body = builder.buildBody(fields: fields, files: files)
        let httpRequest = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: authorizedHeaders(contentType: builder.contentTypeHeaderValue()),
            body: body
        )

        let envelope: BackendEnvelope<BackendGenerationStartData> = try await sendEnvelope(httpRequest, endpointName: "photo/generate/animation")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Generation start payload is empty")
        }
        return data
    }

    func frameToVideo(_ request: FrameToVideoRequest) async throws -> BackendGenerationStartData {
        let endpoint = try makeURL(endpoint: .frameToVideo)
        let builder = MultipartFormDataBuilder()

        var fields: [String: String] = [
            "userId": request.userId,
            "cfgScale": request.cfgScale,
            "duration": request.duration,
            "prompt": request.prompt,
            "modelName": request.modelName,
            "mode": request.mode
        ]

        if let negativePrompt = request.negativePrompt,
           !negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields["negativePrompt"] = negativePrompt
        }

        var files = [
            MultipartFormDataBuilder.File(
                name: "startFrame",
                filename: request.startFrame.fileName,
                mimeType: request.startFrame.mimeType,
                data: request.startFrame.data
            )
        ]

        if let endFrame = request.endFrame {
            files.append(
                MultipartFormDataBuilder.File(
                    name: "endFrame",
                    filename: endFrame.fileName,
                    mimeType: endFrame.mimeType,
                    data: endFrame.data
                )
            )
        }

        let body = builder.buildBody(fields: fields, files: files)
        let httpRequest = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: authorizedHeaders(contentType: builder.contentTypeHeaderValue()),
            body: body
        )

        let envelope: BackendEnvelope<BackendGenerationStartData> = try await sendEnvelope(httpRequest, endpointName: "video/generate/frame")
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Generation start payload is empty")
        }
        return data
    }

    func generateVoice(_ request: VoiceGenRequest) async throws -> BackendGenerationStartData {
        try await postJSONGeneration(endpoint: .voiceGen, payloadData: request.payloadData, endpointName: "clips/minimax15")
    }

    func generateAIImage(_ request: AIImageRequest) async throws -> BackendGenerationStartData {
        let parsedRequest = try decodeAIImageMultipartRequest(from: request.payloadData)
        return try await generateAIImageViaLegacy(parsedRequest)
    }

    func generationStatus(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let endpointURL = try makeURL(
            endpoint: .servicesStatus,
            queryItems: [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "jobId", value: jobId)
            ]
        )

        let request = HTTPRequest(
            url: endpointURL,
            method: .get,
            headers: authorizedHeaders()
        )

        let envelope: BackendEnvelope<BackendGenerationStatusData> = try await sendEnvelope(request, endpointName: "services/status")
        guard let status = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Status payload is empty")
        }

        let normalizedStatus = status.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let errorCode = status.errorCode,
           !errorCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backendMessage(errorCode)
        }

        guard normalizedStatus == "COMPLETED" else {
            throw APIError.backendMessage("Generation status: \(normalizedStatus)")
        }

        guard let resultUrl = status.resultUrl ?? status.audioUrl,
              let parsedResultURL = URL(string: resultUrl) else {
            throw APIError.backendMessage("Result URL is missing")
        }

        let resultData = try await http.sendData(
            HTTPRequest(url: parsedResultURL, method: .get)
        )

        var previewData: Data?
        if status.isVideo,
           let preview = status.preview,
           let previewURL = URL(string: preview) {
            previewData = try? await http.sendData(
                HTTPRequest(url: previewURL, method: .get)
            )
        }

        return BackendGenerationStatusPayload(
            isVideo: status.isVideo,
            resultData: resultData,
            previewData: previewData
        )
    }
}

private extension MiniMaxBackendServiceImpl {
    func generateAIImageViaLegacy(_ parsedRequest: AIImageMultipartRequest) async throws -> BackendGenerationStartData {
        let endpoint = try makeURL(endpoint: .aiImage)
        let builder = MultipartFormDataBuilder()

        var fields: [String: String] = [
            "userId": parsedRequest.userId,
            "prompt": parsedRequest.prompt,
            "quality": parsedRequest.quality
        ]

        if let size = parsedRequest.size {
            fields["size"] = size
        }
        if let aspectRatio = parsedRequest.aspectRatio {
            fields["aspectRatio"] = aspectRatio
        }
        if let noPrompt = parsedRequest.noPrompt {
            fields["noPrompt"] = noPrompt
        }

        let files: [MultipartFormDataBuilder.File]
        if let imageData = parsedRequest.imageData {
            files = [
                MultipartFormDataBuilder.File(
                    name: "image",
                    filename: parsedRequest.imageFileName,
                    mimeType: parsedRequest.imageMimeType,
                    data: imageData
                )
            ]
        } else {
            files = []
        }

        let body = builder.buildBody(fields: fields, files: files)
        let httpRequest = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: authorizedHeaders(contentType: builder.contentTypeHeaderValue()),
            body: body
        )

        let envelope: BackendEnvelope<BackendGenerationStartData> = try await sendEnvelope(
            httpRequest,
            endpointName: "photo/generate/txt2img"
        )
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Generation start payload is empty")
        }
        return data
    }

    func postJSONGeneration(
        endpoint: MiniMaxBackendEndpoint,
        payloadData: Data,
        endpointName: String
    ) async throws -> BackendGenerationStartData {
        let endpointURL = try makeURL(endpoint: endpoint)

        let request = HTTPRequest(
            url: endpointURL,
            method: .post,
            headers: authorizedHeaders(),
            body: payloadData
        )

        let envelope: BackendEnvelope<BackendGenerationStartData> = try await sendEnvelope(request, endpointName: endpointName)
        guard let data = envelope.data else {
            throw APIError.backendMessage(envelope.message ?? "Generation start payload is empty")
        }
        return data
    }

    func decodeAIImageMultipartRequest(from payloadData: Data) throws -> AIImageMultipartRequest {
        let rawObject = try JSONSerialization.jsonObject(with: payloadData)
        guard let dictionary = rawObject as? [String: Any] else {
            throw APIError.backendMessage("AI Image payload must be a JSON object")
        }

        let userId = Self.readString(from: dictionary, key: "userId")
        let prompt = Self.readString(from: dictionary, key: "prompt")

        guard !userId.isEmpty else {
            throw APIError.backendMessage("AI Image payload: userId is required")
        }
        guard !prompt.isEmpty else {
            throw APIError.backendMessage("AI Image payload: prompt is required")
        }

        let quality = Self.normalizedQuality(from: dictionary["quality"]) ?? "high"
        var size = Self.normalizedSize(from: dictionary["size"])
        let aspectRatio = Self.normalizedAspectRatio(from: dictionary["aspectRatio"])

        if size == nil, aspectRatio == nil {
            size = "1024x1024"
        }

        let noPromptValue = Self.readString(from: dictionary, key: "noPrompt")
        let noPrompt = noPromptValue.isEmpty ? nil : noPromptValue
        let templateId = Self.normalizedTemplateId(from: dictionary["templateId"])
        let imageDataPayload = Self.readImagePayload(from: dictionary)

        return AIImageMultipartRequest(
            userId: userId,
            prompt: prompt,
            quality: quality,
            size: size,
            aspectRatio: aspectRatio,
            noPrompt: noPrompt,
            templateId: templateId,
            imageData: imageDataPayload?.data,
            imageMimeType: imageDataPayload?.mimeType ?? "image/jpeg",
            imageFileName: imageDataPayload?.fileName ?? "image.jpg"
        )
    }

    static func normalizedQuality(from rawValue: Any?) -> String? {
        guard let value = stringValue(from: rawValue)?.lowercased() else { return nil }
        switch value {
        case "high", "medium", "low", "auto":
            return value
        default:
            return nil
        }
    }

    static func normalizedSize(from rawValue: Any?) -> String? {
        guard let value = stringValue(from: rawValue) else { return nil }
        switch value {
        case "1024x1024", "1536x1024", "1024x1536":
            return value
        default:
            return nil
        }
    }

    static func normalizedAspectRatio(from rawValue: Any?) -> String? {
        guard let value = stringValue(from: rawValue) else { return nil }
        switch value {
        case "1:1", "3:2", "2:3", "16:9", "9:16", "4:3", "3:4":
            return value
        default:
            return nil
        }
    }

    static func normalizedTemplateId(from rawValue: Any?) -> Int? {
        guard let value = stringValue(from: rawValue),
              let parsed = Int(value),
              parsed > 0 else {
            return nil
        }
        return parsed
    }

    static func sizeValue(from aspectRatio: String?) -> String? {
        guard let aspectRatio else { return nil }
        switch aspectRatio {
        case "1:1":
            return "1024x1024"
        case "16:9", "3:2":
            return "1536x1024"
        case "9:16", "2:3":
            return "1024x1536"
        case "4:3":
            return "1365x1024"
        case "3:4":
            return "1024x1365"
        default:
            return nil
        }
    }

    static func readString(from dictionary: [String: Any], key: String) -> String {
        String(describing: dictionary[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stringValue(from rawValue: Any?) -> String? {
        guard let rawValue else { return nil }
        let value = String(describing: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func readImagePayload(from dictionary: [String: Any]) -> AIImageImagePayload? {
        if let imageBase64 = stringValue(from: dictionary["imageBase64"]),
           let decoded = decodeBase64Payload(imageBase64) {
            return AIImageImagePayload(
                data: decoded.data,
                mimeType: decoded.mimeType,
                fileName: decoded.fileName
            )
        }

        if let imageValue = stringValue(from: dictionary["image"]),
           let decoded = decodeBase64Payload(imageValue) {
            return AIImageImagePayload(
                data: decoded.data,
                mimeType: decoded.mimeType,
                fileName: decoded.fileName
            )
        }

        return nil
    }

    static func decodeBase64Payload(_ rawValue: String) -> (data: Data, mimeType: String, fileName: String)? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var mimeType = "image/jpeg"
        var fileName = "image.jpg"
        var base64Part = trimmed

        if trimmed.hasPrefix("data:"),
           let commaIndex = trimmed.firstIndex(of: ",") {
            let prefix = String(trimmed[..<commaIndex])
            base64Part = String(trimmed[trimmed.index(after: commaIndex)...])

            if prefix.contains("image/png") {
                mimeType = "image/png"
                fileName = "image.png"
            } else if prefix.contains("image/webp") {
                mimeType = "image/webp"
                fileName = "image.webp"
            } else if prefix.contains("image/jpeg") || prefix.contains("image/jpg") {
                mimeType = "image/jpeg"
                fileName = "image.jpg"
            }
        }

        guard let data = Data(base64Encoded: base64Part, options: [.ignoreUnknownCharacters]),
              !data.isEmpty else {
            return nil
        }

        return (data: data, mimeType: mimeType, fileName: fileName)
    }

    func makeURL(
        endpoint: MiniMaxBackendEndpoint,
        baseURL: URL? = nil,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        let resolvedBaseURL = baseURL ?? config.baseURL
        var components = URLComponents(url: endpoint.url(baseURL: resolvedBaseURL), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        return url
    }

    func authorizedHeaders(contentType: String = "application/json") -> [String: String] {
        [
            "Authorization": "Bearer \(config.bearerToken)",
            "Content-Type": contentType,
            "Accept": "application/json"
        ]
    }

    func sendEnvelope<T: Decodable>(_ request: HTTPRequest, endpointName: String) async throws -> BackendEnvelope<T> {
        let data = try await http.sendData(request)
        let envelope: BackendEnvelope<T>

        do {
            envelope = try decoder.decode(BackendEnvelope<T>.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }

        if envelope.error {
            let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            let code = envelope.code?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "API error on \(endpointName)"
            if let message, !message.isEmpty {
                throw APIError.backendMessage(message)
            }
            if let code, !code.isEmpty {
                throw APIError.backendMessage(code)
            }
            throw APIError.backendMessage(fallback)
        }

        return envelope
    }
}

private extension MiniMaxBackendServiceImpl {
    struct AIImageMultipartRequest {
        let userId: String
        let prompt: String
        let quality: String
        let size: String?
        let aspectRatio: String?
        let noPrompt: String?
        let templateId: Int?
        let imageData: Data?
        let imageMimeType: String
        let imageFileName: String
    }

    struct AIImageImagePayload {
        let data: Data
        let mimeType: String
        let fileName: String
    }
}
