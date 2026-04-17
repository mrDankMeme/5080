import Alamofire
import Combine
import Foundation
import OSLog

@MainActor
final class APIManager: ObservableObject {
    static let shared = APIManager()

    private let baseURL = "https://aiapppromm.site/api/v1/"
    private let bearer = "245f6302-8239-4ff1-819e-f5c5bb2378a4"
    private let mockImageGenerationJobId = "463c17a4-b554-4441-a167-0c2250aead56"
    private let mockAnimateGenerationJobId = "81e66176-6358-4a19-9ba1-97b84bfcc698"
    var source = "com.meh.5046pictory"

    @Published var templates: [TemplateItem] = []
    @Published var allEffects: [EffectWithTemplate] = []
    @Published var previewEffects: [EffectWithTemplate] = []
    @Published var isTemplatesLoading = false
    @Published var photoStyles: [PhotoStyleItem] = []
    @Published var isPhotoStylesLoading = false
    @Published var servicePrices: ServicePricesData?

    private let useMock: Bool
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pictory5046", category: "APIManager")
    private let decoder = JSONDecoder()

    private var headers: HTTPHeaders {
        [
            "Authorization": "Bearer \(bearer)",
            "Content-Type": "application/json"
        ]
    }

    private init() {
        #if DEBUG
            self.useMock = false
        #else
            self.useMock = false
        #endif
    }

    // MARK: - Auth

    func authorize() async {
        let userId = PurchaseManager.shared.userId

        let params: [String: String] = [
            "userId": userId,
            "gender": "f",
            "source": source,
            "isFb": "0",
            "payments": "1"
        ]

        logger.info("APIManager: Authorizing user \(userId)")

        do {
            let response = try await AF.request(
                baseURL + "user/login",
                method: .post,
                parameters: params,
                encoding: URLEncoding.queryString,
                headers: headers
            )
            .validate()
            .serializingDecodable(AuthResponse.self)
            .value

            if response.error {
                logger.error("APIManager: Auth failed — \(response.message ?? "unknown error")")
            } else {
                let data = response.data
                PurchaseManager.shared.updateAvailableGenerations(data?.availableGenerations ?? 0)
                logger.info("APIManager: Auth success, userId: \(data?.userId ?? ""), generations: \(data?.availableGenerations ?? 0)")
            }
        } catch {
            logger.error("APIManager: Auth request failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Profile

    func fetchProfile() async {
        let userId = PurchaseManager.shared.userId

        let params: [String: String] = [
            "userId": userId
        ]

        logger.info("APIManager: Fetching profile for \(userId)")

        do {
            let response = try await AF.request(
                baseURL + "user/profile",
                method: .get,
                parameters: params,
                encoding: URLEncoding.queryString,
                headers: headers
            )
            .validate()
            .serializingDecodable(ProfileResponse.self)
            .value

            if response.error {
                logger.error("APIManager: Profile failed — \(response.message ?? "unknown error")")
            } else {
                let data = response.data
                PurchaseManager.shared.updateAvailableGenerations(data?.availableGenerations ?? 0)
                logger.info("APIManager: Profile success — generations: \(data?.availableGenerations ?? 0), plan: \(data?.planInfo?.title ?? "none"), isActivePlan: \(data?.isActivePlan ?? false)")
            }
        } catch {
            logger.error("APIManager: Profile request failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Service Prices

    func fetchServicePrices() async {
        let userId = PurchaseManager.shared.userId
        let params: [String: String] = [
            "userId": userId
        ]

        logger.info("APIManager: Fetching service prices for \(userId)")

        do {
            let response = try await AF.request(
                baseURL + "services/prices",
                method: .get,
                parameters: params,
                encoding: URLEncoding.queryString,
                headers: headers
            )
            .validate()
            .serializingDecodable(ServicePricesResponse.self)
            .value

            if response.error {
                logger.error("APIManager: Service prices failed — \(response.message ?? "unknown error")")
            } else {
                servicePrices = response.data
                PurchaseManager.shared.updateServicePrices(response.data)
                logger.info("APIManager: Service prices success — \(response.data?.pricesByKey.count ?? 0) entries")
            }
        } catch {
            logger.error("APIManager: Service prices request failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding

    func completeOnboarding() async {
        let userId = PurchaseManager.shared.userId
        guard let userIdData = userId.data(using: .utf8) else {
            logger.error("APIManager: Onboarding completion failed — invalid userId")
            return
        }

        logger.info("APIManager: Sending onboarding completion for \(userId)")

        let response = await AF.upload(
            multipartFormData: { form in
                form.append(userIdData, withName: "userId")
            },
            to: baseURL + "user/onboarding",
            method: .post,
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .validate()
        .serializingData()
        .response

        if let apiErrorMessage = apiErrorMessage(from: response.data) {
            logger.error("APIManager: Onboarding completion API error — \(apiErrorMessage)")
            return
        }

        if let requestError = response.error {
            logger.error("APIManager: Onboarding completion request failed — \(requestError.localizedDescription)")
            return
        }

        logger.info("APIManager: Onboarding completion success")
    }
    
    // MARK: - Photo Styles

    func fetchPhotoStyles() async {
        isPhotoStylesLoading = true
        defer { isPhotoStylesLoading = false }

        let userId = PurchaseManager.shared.userId

        if useMock {
            let response = await loadMock(fileName: "styles", type: PhotoStylesResponse.self)
            let raw = response?.data ?? []
            photoStyles = raw.filter { !($0.title ?? "").isEmpty }
            logger.info("APIManager: Photo styles mock success — \(self.photoStyles.count) styles")
            return
        }

        let params: [String: String] = [
            "userId": userId,
            "lang": "en",
            "gender": "f",
            "showAll": "1"
        ]

        logger.info("APIManager: Fetching photo styles for \(userId)")

        do {
            let response = try await AF.request(
                baseURL + "photo/styles",
                method: .get,
                parameters: params,
                encoding: URLEncoding.queryString,
                headers: headers
            )
            .validate()
            .serializingDecodable(PhotoStylesResponse.self)
            .value

            if response.error {
                logger.error("APIManager: Photo styles failed — \(response.message ?? "unknown error")")
            } else {
                let raw = response.data ?? []
                photoStyles = raw.filter { !($0.title ?? "").isEmpty }
                logger.info("APIManager: Photo styles success — \(self.photoStyles.count) styles")
            }
        } catch {
            logger.error("APIManager: Photo styles request failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Effects (Templates)

    func fetchTemplates() async {
        isTemplatesLoading = true
        defer { isTemplatesLoading = false }

        let userId = PurchaseManager.shared.userId
        let userToken = userId

        if useMock {
            let response = await loadMock(fileName: "templates", type: EffectsListResponse.self)
            templates = response?.data?.list.filter { !($0.title ?? "").isEmpty } ?? []
            updateEffectsLists()
            return
        }

        let params: [String: String] = [
            "userId": userId,
            "userToken": userToken,
            "lang": "en",
            "gender": "f"
        ]

        logger.info("APIManager: Fetching effects for \(userId)")

        do {
            let response = try await AF.request(
                baseURL + "effects/list",
                method: .get,
                parameters: params,
                encoding: URLEncoding.queryString,
                headers: headers
            )
            .validate()
            .serializingDecodable(EffectsListResponse.self)
            .value

            if response.error {
                logger.error("APIManager: Effects failed — \(response.message ?? "unknown error")")
            } else {
                let raw = response.data?.list ?? []
                templates = raw.filter { !($0.title ?? "").isEmpty }
                updateEffectsLists()
                logger.info("APIManager: Effects success — \(self.templates.count) categories, \(self.allEffects.count) effects")
            }
        } catch {
            logger.error("APIManager: Effects request failed — \(error.localizedDescription)")
        }
    }

    private func updateEffectsLists() {
        allEffects = templates.flatMap { template in
            template.effects.filter { $0.isEnabled }.map { effect in
                EffectWithTemplate(effect: effect, template: template)
            }
        }
        previewEffects = templates.compactMap { template in
            guard let first = template.effects.first(where: { $0.isEnabled }) else { return nil }
            return EffectWithTemplate(effect: first, template: template)
        }
    }

    private struct APIErrorEnvelope: Decodable {
        let error: Bool
        let code: String?
        let message: String?
    }

    private func decodeGenerationResponse<T: Decodable>(
        _ response: AFDataResponse<Data>,
        as type: T.Type,
        endpoint: String
    ) throws -> T {
        if let apiErrorMessage = apiErrorMessage(from: response.data) {
            logger.error("APIManager: \(endpoint) API error — \(apiErrorMessage)")
            throw GenerationStatusError.apiError(apiErrorMessage)
        }

        if let requestError = response.error {
            logger.error("APIManager: \(endpoint) request failed — \(requestError.localizedDescription)")
            throw GenerationStatusError.apiError(requestError.localizedDescription)
        }

        guard let data = response.data else {
            logger.error("APIManager: \(endpoint) empty response")
            throw GenerationStatusError.noData
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.error("APIManager: \(endpoint) decode failed — \(error.localizedDescription)")
            throw GenerationStatusError.apiError("Invalid server response")
        }
    }

    private func apiErrorMessage(from data: Data?) -> String? {
        guard let data,
              let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data),
              envelope.error
        else {
            return nil
        }

        if let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty
        {
            return message
        }

        if let code = envelope.code?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty
        {
            return code
        }

        return "Unknown API error"
    }

    // MARK: - Generate Effect

    /// Starts generation for a template (effect).
    /// - Parameters:
    ///   - effectWithTemplate: selected effect with its parent group
    ///   - photoData: image data
    /// - Returns: jobId for subsequent status checks
    /// - Throws: Error when the response is unsuccessful
    func generateEffect(effectWithTemplate: EffectWithTemplate, photoData: Data) async throws -> String {
        try await generateEffect(templateId: effectWithTemplate.effect.id, photoData: photoData)
    }

    func generateEffect(templateId: Int, photoData: Data) async throws -> String {
        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockImageGenerationJobId
        }

        let userId = PurchaseManager.shared.userId
        let userToken = userId
        let templateIdRaw = String(templateId)

        logger.info("APIManager: Starting effect generation, templateId: \(templateIdRaw)")

        let rawResponse = await AF.upload(
            multipartFormData: { form in
                form.append(userId.data(using: .utf8)!, withName: "userId")
                form.append(userToken.data(using: .utf8)!, withName: "userToken")
                form.append(templateIdRaw.data(using: .utf8)!, withName: "templateId")
                form.append(photoData, withName: "photo", fileName: "photo.jpg", mimeType: "image/jpeg")
            },
            to: baseURL + "effects/generate",
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateEffectResponse.self, endpoint: "effects/generate")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: Generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Enhance Photo

    /// Starts upscale generation.
    /// - Parameters:
    ///   - photoData: source photo data
    /// - Returns: jobId for subsequent status checks

    func enhancePhoto(photoData: Data) async throws -> String {
        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockImageGenerationJobId
        }

        let userId = PurchaseManager.shared.userId

        logger.info("APIManager: Starting upscale generation")

        let rawResponse = await AF.upload(
            multipartFormData: { form in
                form.append(userId.data(using: .utf8)!, withName: "userId")
                form.append(photoData, withName: "image", fileName: "photo.jpg", mimeType: "image/jpeg")
            },
            to: baseURL + "photo/generate/upscale",
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "photo/generate/upscale")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: upscale generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Generate Video

    /// Starts video generation using promt.
    /// - Parameters:
    ///   - prompt: text prompt
    /// - Returns: jobId for subsequent status checks
    func generateVideo(prompt: String) async throws -> String {
        let userId = PurchaseManager.shared.userId

        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockAnimateGenerationJobId
        }

        logger.info("APIManager: Starting Video generation")

        let rawResponse = await AF.upload(
            multipartFormData: { form in
                form.append(userId.data(using: .utf8)!, withName: "userId")
                form.append("0.5".data(using: .utf8)!, withName: "cfgScale")
                form.append("5".data(using: .utf8)!, withName: "duration")
                form.append("9:16".data(using: .utf8)!, withName: "aspectRatio")
                form.append(prompt.data(using: .utf8)!, withName: "prompt")
                form.append("kling-v2-master".data(using: .utf8)!, withName: "modelName")
                form.append("std".data(using: .utf8)!, withName: "mode")
                form.append("".data(using: .utf8)!, withName: "negativePrompt")
            },
            to: baseURL + "video/generate/txt2video",
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "video/generate/txt2video")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: Video generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Generate Text To Photo

    /// Starts textToPhoto generation (txt2imgBasic).
    /// - Parameters:
    ///   - prompt: text prompt
    ///   - style: selected style
    /// - Returns: jobId for subsequent status checks
    func textToPhoto(prompt: String, style: PhotoStyleItem?) async throws -> String {
        try await textToPhoto(prompt: prompt, templateId: style?.preferredTemplateId, styleId: style?.id)
    }

    func textToPhoto(prompt: String, templateId: Int?, styleId: Int? = nil) async throws -> String {
        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockImageGenerationJobId
        }

        let userId = PurchaseManager.shared.userId

        var params: [String: String]
        if let templateId = templateId {
            params = [
                "userId": userId,
                "prompt": prompt,
                "templateId": String(templateId)
            ]
        } else {
            params = [
                "userId": userId,
                "prompt": prompt
            ]
        }

        logger.info("APIManager: Starting textToPhoto generation")

        let rawResponse = await AF.request(
            baseURL + "photo/generate/txt2imgBasic",
            method: .post,
            parameters: params,
            encoding: URLEncoding.queryString,
            headers: headers
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "photo/generate/txt2imgBasic")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: textToPhoto generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Generate Edit Photo

    /// Starts editPhoto generation (img2imgBasic).
    /// - Parameters:
    ///   - prompt: text prompt
    ///   - style: selected style
    ///   - photoData: source photo data
    /// - Returns: jobId for subsequent status checks
    func editPhoto(prompt: String, style: PhotoStyleItem?, photoData: Data) async throws -> String {
        try await editPhoto(prompt: prompt, templateId: style?.preferredTemplateId, styleId: style?.id, photoData: photoData)
    }

    func editPhoto(prompt: String, templateId: Int?, styleId: Int? = nil, photoData: Data) async throws -> String {
        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockImageGenerationJobId
        }

        let userId = PurchaseManager.shared.userId

        logger.info("APIManager: Starting editPhoto generation")

        var rawResponse: DataResponse<Data, AFError>
        if let templateId = templateId {
            rawResponse = await AF.upload(
                multipartFormData: { form in
                    form.append(userId.data(using: .utf8)!, withName: "userId")
                    form.append(prompt.data(using: .utf8)!, withName: "prompt")
                    form.append(String(templateId).data(using: .utf8)!, withName: "templateId")
                    form.append(photoData, withName: "photo", fileName: "photo.jpg", mimeType: "image/jpeg")
                },
                to: baseURL + "photo/generate/img2imgBasic",
                headers: ["Authorization": "Bearer \(bearer)"]
            )
            .serializingData()
            .response
        } else {
            rawResponse = await AF.upload(
                multipartFormData: { form in
                    form.append(userId.data(using: .utf8)!, withName: "userId")
                    form.append(prompt.data(using: .utf8)!, withName: "prompt")
                    form.append(photoData, withName: "photo", fileName: "photo.jpg", mimeType: "image/jpeg")
                },
                to: baseURL + "photo/generate/img2imgBasic",
                headers: ["Authorization": "Bearer \(bearer)"]
            )
            .serializingData()
            .response
        }

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "photo/generate/img2imgBasic")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: editPhoto generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Generate Frame Video

    /// Starts video generation using two frames and promt.
    /// - Parameters:
    ///   - prompt: text prompt
    ///   - startFrameData: data for the first frame
    ///   - endFrameData: data for the second frame
    /// - Returns: jobId for subsequent status checks
    func generateFrameVideo(prompt: String, startFrameData: Data, endFrameData: Data) async throws -> String {
        let userId = PurchaseManager.shared.userId

        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockAnimateGenerationJobId
        }

        logger.info("APIManager: Starting Frame Video generation")

        let rawResponse = await AF.upload(
            multipartFormData: { form in
                form.append(userId.data(using: .utf8)!, withName: "userId")
                form.append("0.5".data(using: .utf8)!, withName: "cfgScale")
                form.append("5".data(using: .utf8)!, withName: "duration")
                form.append(prompt.data(using: .utf8)!, withName: "prompt")
                form.append("kling-v1-6".data(using: .utf8)!, withName: "modelName")
                form.append("std".data(using: .utf8)!, withName: "mode")
                form.append(startFrameData, withName: "startFrame", fileName: "startFrame.jpg", mimeType: "image/jpeg")
                form.append(endFrameData, withName: "endFrame", fileName: "endFrame.jpg", mimeType: "image/jpeg")
                form.append("".data(using: .utf8)!, withName: "negativePrompt")
            },
            to: baseURL + "video/generate/frame",
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "video/generate/frame")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: Frame Video generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Animate photo

    /// Starts video generation using frame and promt.
    /// - Parameters:
    ///   - prompt: text prompt
    ///   - frameData: data for the first frame
    /// - Returns: jobId for subsequent status checks
    func animatePhoto(prompt: String, frameData: Data) async throws -> String {
        let userId = PurchaseManager.shared.userId

        if useMock {
            try? await Task.sleep(for: .seconds(1))
            return mockAnimateGenerationJobId
        }

        logger.info("APIManager: Starting Animate Photo generation")

        let rawResponse = await AF.upload(
            multipartFormData: { form in
                form.append(userId.data(using: .utf8)!, withName: "userId")
                form.append(prompt.data(using: .utf8)!, withName: "prompt")
                form.append(frameData, withName: "file", fileName: "frameData.jpg", mimeType: "image/jpeg")
            },
            to: baseURL + "photo/generate/animation",
            headers: ["Authorization": "Bearer \(bearer)"]
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerateFrameResponse.self, endpoint: "photo/generate/animation")

        guard let jobId = response.data?.jobId, !jobId.isEmpty else {
            throw GenerationStatusError.noData
        }

        logger.info("APIManager: AnimatePhoto generation started, jobId: \(jobId)")
        return jobId
    }

    // MARK: - Generation Status

    /// Fetches generation status and, on success, returns result data (image/video) from resultUrl.
    /// - Parameters:
    ///   - userId: user ID
    ///   - jobId: generation job ID
    /// - Returns: result data (image or video)
    /// - Throws: Error for errorCode or when status is not COMPLETED
    func getGenerationStatus(userId: String, jobId: String) async throws -> Data {
        let payload = try await getGenerationStatusPayload(userId: userId, jobId: jobId)
        return payload.resultData
    }

    /// Fetches generation status and returns result payload when completed.
    /// For video, it additionally loads preview data from `data.preview`.
    func getGenerationStatusPayload(userId: String, jobId: String) async throws -> GenerationResultPayload {
        let params: [String: String] = [
            "userId": userId,
            "jobId": jobId
        ]

        logger.info("APIManager: Fetching generation status for jobId \(jobId)")

        let rawResponse = await AF.request(
            baseURL + "services/status",
            method: .get,
            parameters: params,
            encoding: URLEncoding.queryString,
            headers: headers
        )
        .serializingData()
        .response

        let response = try decodeGenerationResponse(rawResponse, as: GenerationStatusResponse.self, endpoint: "services/status")

        guard let data = response.data else {
            throw GenerationStatusError.noData
        }

        let status = data.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if let errorCode = data.errorCode, !errorCode.isEmpty {
            throw GenerationStatusError.generationFailed(errorCode)
        }

        if status == "ERROR" || status == "FAILED" {
            throw GenerationStatusError.generationFailed(response.message ?? "Generation failed")
        }

        guard status == "COMPLETED" else {
            throw GenerationStatusError.notCompleted(status: status)
        }

        guard let resultUrlString = data.resultUrl, !resultUrlString.isEmpty else {
            throw GenerationStatusError.noResultUrl
        }

        let resultData = try await downloadResultData(from: resultUrlString)

        var previewData: Data?
        if data.isVideo, let preview = data.preview, !preview.isEmpty {
            previewData = try? await downloadResultData(from: preview)
        }

        logger.info("APIManager: Generation result loaded, isVideo: \(data.isVideo), size: \(resultData.count) bytes")
        return GenerationResultPayload(
            isVideo: data.isVideo,
            resultData: resultData,
            previewData: previewData
        )
    }

    private func downloadResultData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GenerationStatusError.noResultUrl
        }
        return try await AF.request(url)
            .validate()
            .serializingData()
            .value
    }

    // MARK: - Mock

    private func loadMock<T: Decodable>(fileName: String, type: T.Type) async -> T? {
        logger.info("APIManager: Loading mock \(fileName).json")

        try? await Task.sleep(for: .seconds(2))

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            logger.error("APIManager: Mock file \(fileName).json not found in bundle")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            logger.info("APIManager: Mock \(fileName).json loaded successfully")
            return decoded
        } catch {
            logger.error("APIManager: Mock decode failed — \(error.localizedDescription)")
            return nil
        }
    }
}
