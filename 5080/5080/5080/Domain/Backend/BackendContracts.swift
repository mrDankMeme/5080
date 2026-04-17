import Foundation
import Combine

struct BackendEnvelope<T: Decodable>: Decodable {
    let error: Bool
    let code: String?
    let message: String?
    let data: T?
}

struct BackendAuthData: Decodable, Sendable {
    let id: Int?
    let userId: String
    let availableGenerations: Int
    let statTariffId: Int?
    let isActivePlan: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case availableGenerations
        case isActivePlan
        case isActiveSubscription
        case profile
        case stat
    }

    private enum ProfileKeys: String, CodingKey {
        case userId
    }

    private enum StatKeys: String, CodingKey {
        case availableGenerations
        case tariffId
    }

    init(
        id: Int? = nil,
        userId: String,
        availableGenerations: Int,
        statTariffId: Int? = nil,
        isActivePlan: Bool
    ) {
        self.id = id
        self.userId = userId
        self.availableGenerations = availableGenerations
        self.statTariffId = statTariffId
        self.isActivePlan = isActivePlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)

        if let directUserId = try container.decodeIfPresent(String.self, forKey: .userId),
           !directUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userId = directUserId
        } else if let profileContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile),
                  let nestedUserId = try profileContainer.decodeIfPresent(String.self, forKey: .userId),
                  !nestedUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userId = nestedUserId
        } else {
            userId = ""
        }

        let topLevelAvailable = Self.decodeLossyInt(from: container, key: .availableGenerations)
        let statContainer = try? container.nestedContainer(keyedBy: StatKeys.self, forKey: .stat)

        let statAvailable: Int = {
            guard let statContainer else {
                return 0
            }
            return Self.decodeLossyInt(from: statContainer, key: .availableGenerations)
        }()
        availableGenerations = max(topLevelAvailable, statAvailable)
        statTariffId = statContainer.flatMap { Self.decodeLossyOptionalInt(from: $0, key: .tariffId) }

        isActivePlan =
            Self.decodeLossyBool(from: container, key: .isActivePlan) ??
            Self.decodeLossyBool(from: container, key: .isActiveSubscription) ??
            false
    }

    private static func decodeLossyInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return 0
    }

    private static func decodeLossyInt(
        from container: KeyedDecodingContainer<StatKeys>,
        key: StatKeys
    ) -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return 0
    }

    private static func decodeLossyOptionalInt(
        from container: KeyedDecodingContainer<StatKeys>,
        key: StatKeys
    ) -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key),
           doubleValue.isFinite {
            return Int(doubleValue)
        }
        return nil
    }

    private static func decodeLossyBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Bool? {
        if let boolValue = try? container.decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? container.decode(String.self, forKey: key) {
            switch stringValue.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

struct BackendProfileData: Decodable, Sendable {
    let id: Int?
    let userId: String
    let availableGenerations: Int
    let statTariffId: Int?
    let isActivePlan: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case availableGenerations
        case isActivePlan
        case isActiveSubscription
        case profile
        case stat
    }

    private enum ProfileKeys: String, CodingKey {
        case userId
    }

    private enum StatKeys: String, CodingKey {
        case availableGenerations
        case tariffId
    }

    init(
        id: Int? = nil,
        userId: String,
        availableGenerations: Int,
        statTariffId: Int? = nil,
        isActivePlan: Bool
    ) {
        self.id = id
        self.userId = userId
        self.availableGenerations = availableGenerations
        self.statTariffId = statTariffId
        self.isActivePlan = isActivePlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)

        if let directUserId = try container.decodeIfPresent(String.self, forKey: .userId),
           !directUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userId = directUserId
        } else if let profileContainer = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile),
                  let nestedUserId = try profileContainer.decodeIfPresent(String.self, forKey: .userId),
                  !nestedUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userId = nestedUserId
        } else {
            userId = ""
        }

        let topLevelAvailable = Self.decodeLossyInt(from: container, key: .availableGenerations)
        let statContainer = try? container.nestedContainer(keyedBy: StatKeys.self, forKey: .stat)

        let statAvailable: Int = {
            guard let statContainer else {
                return 0
            }
            return Self.decodeLossyInt(from: statContainer, key: .availableGenerations)
        }()
        availableGenerations = max(topLevelAvailable, statAvailable)
        statTariffId = statContainer.flatMap { Self.decodeLossyOptionalInt(from: $0, key: .tariffId) }

        isActivePlan =
            Self.decodeLossyBool(from: container, key: .isActivePlan) ??
            Self.decodeLossyBool(from: container, key: .isActiveSubscription) ??
            false
    }

    private static func decodeLossyInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return 0
    }

    private static func decodeLossyInt(
        from container: KeyedDecodingContainer<StatKeys>,
        key: StatKeys
    ) -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return 0
    }

    private static func decodeLossyOptionalInt(
        from container: KeyedDecodingContainer<StatKeys>,
        key: StatKeys
    ) -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key),
           doubleValue.isFinite {
            return Int(doubleValue)
        }
        return nil
    }

    private static func decodeLossyBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Bool? {
        if let boolValue = try? container.decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? container.decode(String.self, forKey: key) {
            switch stringValue.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

struct BackendGenerationStartData: Decodable, Sendable {
    let id: Int?
    let generationId: Int?
    let jobId: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case generationId
        case jobId
        case status
    }

    init(id: Int? = nil, generationId: Int? = nil, jobId: String? = nil, status: String? = nil) {
        self.id = id
        self.generationId = generationId
        self.jobId = jobId
        self.status = status
    }

    init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            if unkeyedContainer.isAtEnd {
                self.init()
                return
            }

            let firstPayload = try unkeyedContainer.decode(GenerationStartPayload.self)
            self.init(
                id: firstPayload.id,
                generationId: firstPayload.generationId,
                jobId: firstPayload.jobId,
                status: firstPayload.status
            )
            return
        }

        let payload = try GenerationStartPayload(from: decoder)
        self.init(
            id: payload.id,
            generationId: payload.generationId,
            jobId: payload.jobId,
            status: payload.status
        )
    }

    private struct GenerationStartPayload: Decodable {
        let id: Int?
        let generationId: Int?
        let jobId: String?
        let status: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decodeIfPresent(Int.self, forKey: .id)
            generationId = try container.decodeIfPresent(Int.self, forKey: .generationId)
            status = try container.decodeIfPresent(String.self, forKey: .status)

            if let jobIdString = try container.decodeIfPresent(String.self, forKey: .jobId) {
                jobId = jobIdString
            } else if let jobIdInt = try container.decodeIfPresent(Int.self, forKey: .jobId) {
                jobId = String(jobIdInt)
            } else {
                jobId = nil
            }
        }
    }
}

struct BackendGenerationStatusData: Decodable, Sendable {
    let id: Int?
    let generationId: Int?
    let jobId: String?
    let preview: String?
    let resultUrl: String?
    let audioUrl: String?
    let isVideo: Bool
    let status: String
    let errorCode: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case generationId
        case jobId
        case preview
        case resultUrl
        case audioUrl
        case isVideo
        case status
        case errorCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        generationId = try container.decodeIfPresent(Int.self, forKey: .generationId)
        jobId = try container.decodeIfPresent(String.self, forKey: .jobId)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        resultUrl = try container.decodeIfPresent(String.self, forKey: .resultUrl)
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)
        status = try container.decode(String.self, forKey: .status)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)

        if let boolValue = try? container.decode(Bool.self, forKey: .isVideo) {
            isVideo = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isVideo) {
            isVideo = intValue != 0
        } else {
            isVideo = false
        }
    }
}

struct BackendGenerationStatusPayload: Sendable {
    let isVideo: Bool
    let resultData: Data
    let previewData: Data?
}

struct BackendAvailableBonusItem: Decodable, Sendable {
    let day: String
    let maxTokens: String
    let availableTokens: String
    let isCollected: Bool

    private enum CodingKeys: String, CodingKey {
        case day
        case maxTokens
        case availableTokens
        case isCollected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = (try? container.decode(String.self, forKey: .day)) ?? ""
        maxTokens = Self.decodeLossyString(from: container, forKey: .maxTokens)
        availableTokens = Self.decodeLossyString(from: container, forKey: .availableTokens)

        if let boolValue = try? container.decode(Bool.self, forKey: .isCollected) {
            isCollected = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isCollected) {
            isCollected = intValue != 0
        } else {
            isCollected = false
        }
    }

    private static func decodeLossyString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return "0"
    }
}

struct BackendServicePricesData: Decodable, Sendable {
    let pricesByKey: [String: Int]
    let klingPriceModelDuration: [BackendKlingModelPrice]
    let klingPrice: [BackendKlingModelPrice]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var parsedPrices: [String: Int] = [:]
        var parsedKlingPriceModelDuration: [BackendKlingModelPrice] = []
        var parsedKlingPrice: [BackendKlingModelPrice] = []

        for key in container.allKeys {
            if key.stringValue == "klingPriceModelDuration" {
                parsedKlingPriceModelDuration = (try? container.decode([BackendKlingModelPrice].self, forKey: key)) ?? []
                continue
            }

            if key.stringValue == "klingPrice" {
                parsedKlingPrice = (try? container.decode([BackendKlingModelPrice].self, forKey: key)) ?? []
                continue
            }

            if let price = try? container.decode(Int.self, forKey: key) {
                parsedPrices[key.stringValue] = price
            }
        }

        self.pricesByKey = parsedPrices
        self.klingPriceModelDuration = parsedKlingPriceModelDuration
        self.klingPrice = parsedKlingPrice
    }
}

struct BackendKlingModelPrice: Decodable, Sendable, Hashable {
    let model: String
    let seconds: [BackendKlingDurationPrice]
}

struct BackendKlingDurationPrice: Decodable, Sendable, Hashable {
    let duration: Int
    let price: Int
}

enum BackendKlingGenerationKind: Sendable {
    case textToVideo
    case imageToVideo
    case elementsToVideo

    fileprivate var pricingSuffix: String {
        switch self {
        case .textToVideo:
            return "txt2video"
        case .imageToVideo:
            return "img2video"
        case .elementsToVideo:
            return "elements2video"
        }
    }
}

extension BackendServicePricesData {
    func klingDurationPriceMap(
        requestModelName: String,
        mode: String = "std",
        generationKind: BackendKlingGenerationKind
    ) -> [Int: Int] {
        let normalizedRequestModelName = requestModelName.klingPricingToken

        if let durationPrices = klingPriceModelDuration.first(where: {
            $0.model.klingPricingToken == normalizedRequestModelName
        })?.seconds {
            return durationPrices.reduce(into: [Int: Int]()) { result, item in
                result[item.duration] = item.price
            }
        }

        guard let pricingModelName = klingPricingModelName(
            requestModelName: requestModelName,
            mode: mode,
            generationKind: generationKind
        ) else {
            return [:]
        }

        guard let durationPrices = klingPrice.first(where: { $0.model == pricingModelName })?.seconds else {
            return [:]
        }

        return durationPrices.reduce(into: [Int: Int]()) { result, item in
            result[item.duration] = item.price
        }
    }

    private func klingPricingModelName(
        requestModelName: String,
        mode: String,
        generationKind: BackendKlingGenerationKind
    ) -> String? {
        let normalizedModelName = requestModelName.klingPricingToken
        let normalizedMode = mode.klingPricingToken

        let family: String
        if normalizedModelName.contains("25") {
            family = "kling25"
        } else if normalizedModelName.contains("21") {
            family = "kling21"
        } else if normalizedModelName.contains("16") || normalizedModelName.isEmpty {
            family = "kling16"
        } else {
            return nil
        }

        let tier: String
        if normalizedModelName.contains("master") || normalizedMode.contains("master") {
            tier = "master"
        } else if normalizedModelName.contains("turbo") || normalizedMode.contains("turbo") {
            tier = "turbo"
        } else if normalizedModelName.contains("pro") || normalizedMode.contains("pro") {
            tier = "pro"
        } else {
            tier = "std"
        }

        return "\(family)\(tier)_\(generationKind.pricingSuffix)"
    }
}

private extension String {
    var klingPricingToken: String {
        lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

struct BackendIgnoredPayload: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}

struct BinaryUpload: Sendable {
    let data: Data
    let fileName: String
    let mimeType: String

    init(data: Data, fileName: String, mimeType: String = "image/jpeg") {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

struct TextToVideoRequest: Sendable {
    let userId: String
    let cfgScale: String
    let duration: String
    let aspectRatio: String
    let prompt: String
    let modelName: String
    let mode: String
    let negativePrompt: String?

    init(
        userId: String,
        cfgScale: String = "0.5",
        duration: String = "5",
        aspectRatio: String = "16:9",
        prompt: String,
        modelName: String = "kling-v1-6",
        mode: String = "std",
        negativePrompt: String? = nil
    ) {
        self.userId = userId
        self.cfgScale = cfgScale
        self.duration = duration
        self.aspectRatio = aspectRatio
        self.prompt = prompt
        self.modelName = modelName
        self.mode = mode
        self.negativePrompt = negativePrompt
    }
}

struct AnimateImageRequest: Sendable {
    let userId: String
    let prompt: String?
    let photoURL: String?
    let file: BinaryUpload
}

struct FrameToVideoRequest: Sendable {
    let userId: String
    let cfgScale: String
    let duration: String
    let prompt: String
    let modelName: String
    let mode: String
    let startFrame: BinaryUpload
    let endFrame: BinaryUpload?
    let negativePrompt: String?

    init(
        userId: String,
        cfgScale: String = "0.5",
        duration: String = "5",
        prompt: String,
        modelName: String = "kling-v1-6-pro",
        mode: String = "std",
        startFrame: BinaryUpload,
        endFrame: BinaryUpload? = nil,
        negativePrompt: String? = nil
    ) {
        self.userId = userId
        self.cfgScale = cfgScale
        self.duration = duration
        self.prompt = prompt
        self.modelName = modelName
        self.mode = mode
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.negativePrompt = negativePrompt
    }
}

struct VoiceGenRequest: Sendable {
    let payloadData: Data

    init(payloadData: Data) {
        self.payloadData = payloadData
    }
}

struct AIImageRequest: Sendable {
    let payloadData: Data

    init(payloadData: Data) {
        self.payloadData = payloadData
    }
}

protocol MiniMaxBackendService: Sendable {
    func authorize(userId: String, gender: String) async throws -> BackendAuthData
    func fetchProfile(userId: String) async throws -> BackendProfileData
    func setFreeGenerations(userId: String) async throws
    func addGenerations(userId: String, productId: Int) async throws
    func collectTokens(userId: String) async throws
    func fetchAvailableBonuses(userId: String) async throws -> [BackendAvailableBonusItem]
    func fetchServicePrices(userId: String) async throws -> BackendServicePricesData

    func textToVideo(_ request: TextToVideoRequest) async throws -> BackendGenerationStartData
    func animateImage(_ request: AnimateImageRequest) async throws -> BackendGenerationStartData
    func frameToVideo(_ request: FrameToVideoRequest) async throws -> BackendGenerationStartData

    func generateVoice(_ request: VoiceGenRequest) async throws -> BackendGenerationStartData
    func generateAIImage(_ request: AIImageRequest) async throws -> BackendGenerationStartData

    func generationStatus(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload
}

enum HistoryCategory: String, CaseIterable, Codable, Sendable {
    case video
    case image
    case voice
    case transcript
}

enum HistoryFlowKind: String, Codable, Sendable {
    case textToVideo
    case animateImage
    case frameToVideo
    case aiImage
    case voiceGen
    case transcribe

    var category: HistoryCategory {
        switch self {
        case .textToVideo, .animateImage, .frameToVideo:
            return .video
        case .aiImage:
            return .image
        case .voiceGen:
            return .voice
        case .transcribe:
            return .transcript
        }
    }

    var displayTitle: String {
        switch self {
        case .textToVideo:
            return "Text to Video"
        case .animateImage:
            return "Animate Photo"
        case .frameToVideo:
            return "Frame to Video"
        case .aiImage:
            return "AI Image"
        case .voiceGen:
            return "Voice Gen"
        case .transcribe:
            return "Transcribe"
        }
    }

    var activeProcessingAlertMessage: String {
        switch self {
        case .textToVideo:
            return "Please wait until your current Text to Video generation is finished before starting another one."
        case .animateImage:
            return "Please wait until your current Animate Photo generation is finished before starting another one."
        case .frameToVideo:
            return "Please wait until your current Frame to Video generation is finished before starting another one."
        case .aiImage:
            return "Please wait until your current AI Image generation is finished before starting another one."
        case .voiceGen:
            return "Please wait until your current voice generation is finished before starting another one."
        case .transcribe:
            return "Please wait until your current transcription is finished before starting another one."
        }
    }

    var activeProcessingAlertTitle: String {
        "Please Wait"
    }
}

enum HistoryEntryStatus: String, Codable, Sendable {
    case processing
    case ready
    case failed
}

enum HistoryTranscribeOutputFormat: String, Codable, Hashable, Sendable {
    case fullText
    case summary
}

struct HistoryTranscriptSegment: Codable, Hashable, Sendable {
    let text: String
    let start: Double
    let end: Double
}

struct HistoryTranscribePayload: Codable, Hashable, Sendable {
    let fileName: String
    let isVideo: Bool
    let outputFormat: HistoryTranscribeOutputFormat
    let timestampsEnabled: Bool
    let transcriptSegments: [HistoryTranscriptSegment]
    let summaryTopics: [String]
    let rawResultJSONString: String
}

struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var prompt: String?
    let flowKind: HistoryFlowKind
    var status: HistoryEntryStatus
    let createdAt: Date
    var updatedAt: Date
    var mediaFileName: String?
    var transcribePayload: HistoryTranscribePayload?
}

enum HistoryRepositoryError: LocalizedError {
    case invalidTitle

    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            return "Invalid file name"
        }
    }
}

@MainActor
protocol HistoryRepository: AnyObject {
    var entriesPublisher: AnyPublisher<[HistoryEntry], Never> { get }
    func entries() -> [HistoryEntry]
    @discardableResult
    func createProcessingEntry(flowKind: HistoryFlowKind, title: String, prompt: String?) -> UUID
    func markEntryReady(
        id: UUID,
        mediaLocalURL: URL?,
        transcribePayload: HistoryTranscribePayload?
    )
    func markEntryFailed(id: UUID)
    func renameEntry(id: UUID, newTitle: String) throws
    func deleteEntry(id: UUID)
    func mediaURL(for entry: HistoryEntry) -> URL?
}

extension HistoryRepository {
    func hasProcessingEntry(flowKind: HistoryFlowKind) -> Bool {
        entries().contains { entry in
            entry.flowKind == flowKind && entry.status == .processing
        }
    }
}
