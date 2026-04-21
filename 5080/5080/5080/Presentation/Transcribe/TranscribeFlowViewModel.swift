import Foundation
import Combine

@MainActor
final class TranscribeFlowViewModel: ObservableObject {
    enum Route {
        case composer
        case loading
        case result
        case failed
    }

    @Published private(set) var route: Route = .composer
    @Published private(set) var resultViewModel: TranscribeResultSceneViewModel?
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let sceneViewModel: TranscribeSceneViewModel
    let loadingViewModel: TextToVideoLoadingSceneViewModel
    let failedViewModel: TextToVideoFailedSceneViewModel

    private let fetchProfileUseCase: FetchProfileUseCase
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchServicePricesUseCase: FetchServicePricesUseCase
    private let transcribeUseCase: TranscribeUseCase
    private let historyRepository: HistoryRepository
    private let pendingRecoveryStore: PendingHistoryRecoveryStore
    private let purchaseManager: PurchaseManager
    private let billingAccessResolver: BillingAccessResolving
    private let aiProcessingConsentManager: AIProcessingConsentManaging
    private let resultViewModelFactory: (TranscribeResultPayload) -> TranscribeResultSceneViewModel

    private var transcribeTask: Task<Void, Never>?
    private var didLoadProfile = false
    private var currentHistoryEntryID: UUID?
    private var cancellables = Set<AnyCancellable>()

    init(
        sceneViewModel: TranscribeSceneViewModel,
        loadingViewModel: TextToVideoLoadingSceneViewModel,
        failedViewModel: TextToVideoFailedSceneViewModel,
        fetchProfileUseCase: FetchProfileUseCase,
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchServicePricesUseCase: FetchServicePricesUseCase,
        transcribeUseCase: TranscribeUseCase,
        historyRepository: HistoryRepository,
        pendingRecoveryStore: PendingHistoryRecoveryStore,
        purchaseManager: PurchaseManager,
        billingAccessResolver: BillingAccessResolving,
        aiProcessingConsentManager: AIProcessingConsentManaging,
        resultViewModelFactory: @escaping (TranscribeResultPayload) -> TranscribeResultSceneViewModel
    ) {
        self.sceneViewModel = sceneViewModel
        self.loadingViewModel = loadingViewModel
        self.failedViewModel = failedViewModel
        self.fetchProfileUseCase = fetchProfileUseCase
        self.authorizeUserUseCase = authorizeUserUseCase
        self.setFreeGenerationsUseCase = setFreeGenerationsUseCase
        self.addGenerationsUseCase = addGenerationsUseCase
        self.fetchServicePricesUseCase = fetchServicePricesUseCase
        self.transcribeUseCase = transcribeUseCase
        self.historyRepository = historyRepository
        self.pendingRecoveryStore = pendingRecoveryStore
        self.purchaseManager = purchaseManager
        self.billingAccessResolver = billingAccessResolver
        self.aiProcessingConsentManager = aiProcessingConsentManager
        self.resultViewModelFactory = resultViewModelFactory
        self.isSubscribed = purchaseManager.isSubscribed
        self.sceneViewModel.syncAvailableTokens(max(0, purchaseManager.availableGenerations))
        bindPurchaseState()
    }

    static var fallback: TranscribeFlowViewModel {
        TranscribeFlowViewModel(
            sceneViewModel: TranscribeSceneViewModel(),
            loadingViewModel: TextToVideoLoadingSceneViewModel(
                title: "Transcribe",
                heading: "Transcribing File...",
                subtitle: "Extracting text from audio. Please wait."
            ),
            failedViewModel: TextToVideoFailedSceneViewModel(
                title: "Transcribe",
                heading: "Transcription Failed",
                subtitle: "We couldn't process this file. Don't worry, your tokens have not been deducted."
            ),
            fetchProfileUseCase: FallbackFetchProfileUseCase(),
            authorizeUserUseCase: FallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: FallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: FallbackAddGenerationsUseCase(),
            fetchServicePricesUseCase: FallbackFetchServicePricesUseCase(),
            transcribeUseCase: FallbackTranscribeUseCase(),
            historyRepository: InMemoryHistoryRepository(),
            pendingRecoveryStore: PendingHistoryRecoveryFileStore(),
            purchaseManager: PurchaseManager.shared,
            billingAccessResolver: DefaultBillingAccessResolver(
                purchaseManager: PurchaseManager.shared
            ),
            aiProcessingConsentManager: UserDefaultsAIProcessingConsentManager(userDefaults: .standard),
            resultViewModelFactory: { payload in
                TranscribeResultSceneViewModel(payload: payload)
            }
        )
    }

    var hasAcceptedAIProcessingConsent: Bool {
        aiProcessingConsentManager.hasAcceptedConsent
    }

    func acceptAIProcessingConsent() {
        aiProcessingConsentManager.acceptConsent()
    }

    func onAppear() {
        guard !didLoadProfile else { return }
        didLoadProfile = true

        Task { [weak self] in
            await self?.fetchProfileBalance()
        }
    }

    func onDisappear() {
        // Recovery is persisted separately; disappearing UI should not cancel the backend job.
    }

    func startTranscribing() {
        sceneViewModel.clearError()

        guard let selectedMedia = sceneViewModel.selectedMedia else {
            sceneViewModel.showError("Please upload audio or video")
            return
        }

        guard canStartAnotherTranscription() else {
            return
        }

        if let paywallDestination = billingAccessResolver.destinationForGeneration(
            requiredTokens: sceneViewModel.transcribeCost
        ) {
            presentPaywall(paywallDestination)
            return
        }

        guard transcribeTask == nil else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.transcribe.activeProcessingAlertTitle,
                message: HistoryFlowKind.transcribe.activeProcessingAlertMessage
            )
            return
        }

        route = .loading
        let historyID = historyRepository.createProcessingEntry(
            flowKind: .transcribe,
            title: historyTitle(from: selectedMedia.fileName),
            prompt: nil
        )
        currentHistoryEntryID = historyID

        transcribeTask = Task { [weak self] in
            guard let self else { return }
            var cleanupPersistedMediaFileName: String?

            do {
                let selectedOutputFormat = self.sceneViewModel.selectedOutputFormat.requestValue
                let timestampsEnabled = self.sceneViewModel.selectedTimestampsMode.isEnabled

                let userId = await self.resolvedUserID()
                await self.ensureAuthorized(userId: userId)

                let pendingMetadata = PendingTranscribeRecoveryMetadata(
                    fileName: selectedMedia.fileName,
                    isVideo: selectedMedia.isVideo,
                    outputFormat: selectedOutputFormat == .summary ? .summary : .fullText,
                    timestampsEnabled: timestampsEnabled,
                    sourceMimeType: selectedMedia.mimeType,
                    persistedMediaFileName: try TranscribeRecoveryMediaStore.persist(selectedMedia)
                )
                cleanupPersistedMediaFileName = pendingMetadata.persistedMediaFileName
                let pendingStartingRecord = PendingHistoryRecoveryRecord(
                    historyEntryId: historyID,
                    flowKind: .transcribe,
                    recoveryKind: .transcribe,
                    stage: .starting,
                    userId: userId,
                    transcribeMetadata: pendingMetadata
                )
                await self.pendingRecoveryStore.upsert(pendingStartingRecord)

                let binaryUpload = try await TranscribeUploadBuilder.makeBinaryUpload(from: selectedMedia)
                let payloadData = try self.buildPayloadData(userId: userId, isVideo: selectedMedia.isVideo)

                let request = TranscribeRequest(payloadData: payloadData, localFile: binaryUpload)
                let startData = try await self.transcribeUseCase.start(request)
                try Task.checkCancellation()

                let pendingPollingMetadata = pendingMetadata.clearingPersistedMediaReference()
                let pendingPollingRecord = PendingHistoryRecoveryRecord(
                    historyEntryId: historyID,
                    flowKind: .transcribe,
                    recoveryKind: .transcribe,
                    stage: .polling,
                    userId: userId,
                    remoteIdentifier: startData.taskId,
                    transcribeMetadata: pendingPollingMetadata,
                    createdAt: pendingStartingRecord.createdAt
                )
                await self.pendingRecoveryStore.upsert(pendingPollingRecord)
                TranscribeRecoveryMediaStore.remove(fileName: cleanupPersistedMediaFileName)
                cleanupPersistedMediaFileName = nil

                let backendResult = try await self.transcribeUseCase.resume(taskId: startData.taskId)
                try Task.checkCancellation()

                let resultPayload = Self.makeResultPayload(
                    backendResult,
                    selectedFileName: selectedMedia.fileName,
                    isVideo: selectedMedia.isVideo,
                    outputFormat: selectedOutputFormat,
                    timestampsEnabled: timestampsEnabled
                )

                let vm = self.resultViewModelFactory(resultPayload)
                self.resultViewModel = vm

                await self.syncBalanceAfterGeneration(userId: userId)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryReady(
                        id: historyID,
                        mediaLocalURL: nil,
                        transcribePayload: self.makeHistoryPayload(from: resultPayload)
                    )
                }
                self.currentHistoryEntryID = nil

                self.route = .result
            } catch is CancellationError {
                TranscribeRecoveryMediaStore.remove(fileName: cleanupPersistedMediaFileName)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.deleteEntry(id: historyID)
                    self.currentHistoryEntryID = nil
                }
                self.route = .composer
            } catch {
                TranscribeRecoveryMediaStore.remove(fileName: cleanupPersistedMediaFileName)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryFailed(id: historyID)
                    self.currentHistoryEntryID = nil
                }
                self.route = .failed
            }

            self.transcribeTask = nil
        }
    }

    func cancelLoading() {
        transcribeTask?.cancel()
        transcribeTask = nil
        if let historyID = currentHistoryEntryID {
            historyRepository.deleteEntry(id: historyID)
            currentHistoryEntryID = nil
        }
        route = .composer
    }

    func closeResult() {
        resultViewModel = nil
        route = .composer
    }

    func retryAfterFailure() {
        startTranscribing()
    }

    func handleBalanceTap() {
        presentPaywall(billingAccessResolver.destinationForHeaderTap())
    }

    func dismissSubscriptionPaywall() {
        isSubscriptionPaywallPresented = false
    }

    func dismissTokensPaywall() {
        isTokensPaywallPresented = false
    }

    private func fetchProfileBalance() async {
        let userId = await resolvedUserID()
        await ensureAuthorized(userId: userId)

        do {
            let profile = try await fetchProfileUseCase.execute(userId: userId)
            sceneViewModel.syncAvailableTokens(profile.availableGenerations)
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
        } catch {
            let fallbackBalance = max(0, purchaseManager.availableGenerations)
            if fallbackBalance > 0 {
                sceneViewModel.syncAvailableTokens(fallbackBalance)
            }
        }

        do {
            let prices = try await fetchServicePricesUseCase.execute(userId: userId)
            applyTranscribePricing(prices)
        } catch {
            sceneViewModel.updateTranscribeCost(1)
        }
    }

    private func bindPurchaseState() {
        purchaseManager.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isSubscribed = value
            }
            .store(in: &cancellables)

        purchaseManager.$availableGenerations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.sceneViewModel.syncAvailableTokens(max(0, value))
            }
            .store(in: &cancellables)
    }

    private func presentPaywall(_ destination: BillingPaywallDestination) {
        switch destination {
        case .subscription:
            isTokensPaywallPresented = false
            isSubscriptionPaywallPresented = true
        case .tokens:
            isSubscriptionPaywallPresented = false
            isTokensPaywallPresented = true
        }
    }

    private func buildPayloadData(userId: String, isVideo: Bool) throws -> Data {
        let payload: [String: Any] = [
            "device_id": userId,
            "is_video": isVideo
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private static func makeResultPayload(
        _ backendResult: BackendTranscribeResult,
        selectedFileName: String,
        isVideo: Bool,
        outputFormat: TranscribeOutputFormat,
        timestampsEnabled: Bool
    ) -> TranscribeResultPayload {
        let decoded = decodeBackendPayload(from: backendResult.rawResultData)
        let summaryTopics = decoded.summaryTopics.isEmpty
            ? fallbackSummaryTopics(from: decoded.transcriptSegments)
            : decoded.summaryTopics

        return TranscribeResultPayload(
            fileName: selectedFileName,
            isVideo: isVideo,
            outputFormat: outputFormat,
            timestampsEnabled: timestampsEnabled,
            transcriptSegments: decoded.transcriptSegments,
            summaryTopics: summaryTopics,
            rawResultJSONString: backendResult.resultJSONString
        )
    }

    private static func decodeBackendPayload(from data: Data) -> DecodedResult {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let dictionary = jsonObject as? [String: Any] else {
            return DecodedResult(transcriptSegments: [], summaryTopics: [])
        }

        let transcriptionItems = (dictionary["transcription"] as? [[String: Any]]) ?? []
        let transcriptSegments: [TranscribeTranscriptSegment] = transcriptionItems.compactMap { item in
            let text = readString(from: item, keys: ["text"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            let start = readDouble(from: item, keys: ["start"])
            let end = readDouble(from: item, keys: ["end"])

            return TranscribeTranscriptSegment(text: text, start: start, end: max(start, end))
        }

        let summary = (dictionary["summary"] as? [String: Any]) ?? [:]
        let oneTopic = decodeStringArray(summary["one_topic"])
        let topics = decodeStringArray(summary["topics"])
        let actionItems = decodeStringArray(summary["action_items"])

        let summaryTopics: [String]
        if !oneTopic.isEmpty {
            summaryTopics = oneTopic
        } else if !topics.isEmpty {
            summaryTopics = topics
        } else {
            summaryTopics = actionItems
        }

        return DecodedResult(transcriptSegments: transcriptSegments, summaryTopics: summaryTopics)
    }

    private static func fallbackSummaryTopics(from segments: [TranscribeTranscriptSegment]) -> [String] {
        let values = segments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if values.isEmpty {
            return []
        }

        return Array(values.prefix(3))
    }

    private static func decodeStringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard let text = value as? String else {
            return []
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        if trimmed.hasPrefix("["),
           let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let values = object as? [Any] {
            return values
                .map { String(describing: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if trimmed.contains("\n") {
            return trimmed
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return [trimmed]
    }

    private static func readString(from dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dictionary[key] {
                return String(describing: value)
            }
        }
        return ""
    }

    private static func readDouble(from dictionary: [String: Any], keys: [String]) -> Double {
        for key in keys {
            guard let value = dictionary[key] else { continue }

            if let doubleValue = value as? Double {
                return doubleValue
            }

            if let intValue = value as? Int {
                return Double(intValue)
            }

            if let stringValue = value as? String,
               let parsed = Double(stringValue) {
                return parsed
            }
        }
        return 0
    }

    private func resolvedUserID() async -> String {
        purchaseManager.resolveUnifiedUserID()
    }

    private func ensureAuthorized(userId: String) async {
        do {
            let auth = try await authorizeUserUseCase.execute(userId: userId, gender: "m")
            sceneViewModel.syncAvailableTokens(auth.availableGenerations)
            purchaseManager.updateAvailableGenerations(auth.availableGenerations)
        } catch {
            // No-op: follow-up profile request can still succeed if user already exists.
        }
    }

    private func ensureDebugGenerations(userId: String) async {
        #if DEBUG
        guard sceneViewModel.availableTokens < sceneViewModel.transcribeCost else { return }

        do {
            try await setFreeGenerationsUseCase.execute(userId: userId)
        } catch {
            // Continue with profile refresh fallback.
        }

        var tariffId: Int?
        if let profile = try? await fetchProfileUseCase.execute(userId: userId) {
            sceneViewModel.syncAvailableTokens(profile.availableGenerations)
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
            tariffId = profile.statTariffId
        }

        if sceneViewModel.availableTokens < sceneViewModel.transcribeCost,
           let tariffId,
           tariffId > 0 {
            do {
                try await addGenerationsUseCase.execute(userId: userId, productId: tariffId)
            } catch {
                // Keep generation flow resilient in debug mode.
            }
        }

        if let profile = try? await fetchProfileUseCase.execute(userId: userId) {
            sceneViewModel.syncAvailableTokens(profile.availableGenerations)
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
        }
        #endif
    }

    private func syncBalanceAfterGeneration(userId: String) async {
        if let profile = try? await fetchProfileUseCase.execute(userId: userId) {
            sceneViewModel.syncAvailableTokens(profile.availableGenerations)
            purchaseManager.updateAvailableGenerations(profile.availableGenerations)
        }
    }

    private func historyTitle(from fileName: String) -> String {
        let base = NSString(string: fileName)
            .deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            return "Transcribe"
        }
        return String(base.prefix(80))
    }

    private func makeHistoryPayload(from payload: TranscribeResultPayload) -> HistoryTranscribePayload {
        HistoryTranscribePayload(
            fileName: payload.fileName,
            isVideo: payload.isVideo,
            outputFormat: payload.outputFormat == .summary ? .summary : .fullText,
            timestampsEnabled: payload.timestampsEnabled,
            transcriptSegments: payload.transcriptSegments.map {
                HistoryTranscriptSegment(text: $0.text, start: $0.start, end: $0.end)
            },
            summaryTopics: payload.summaryTopics,
            rawResultJSONString: payload.rawResultJSONString
        )
    }

    private func applyTranscribePricing(_ prices: BackendServicePricesData) {
        let cost = max(
            1,
            prices.pricesByKey["transcribe"] ??
            prices.pricesByKey["transcription"] ??
            prices.pricesByKey["speech2text"] ??
            prices.pricesByKey["stt"] ??
            prices.pricesByKey["generate"] ??
            1
        )
        sceneViewModel.updateTranscribeCost(cost)
    }

    private func canStartAnotherTranscription() -> Bool {
        guard !historyRepository.hasProcessingEntry(flowKind: .transcribe) else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.transcribe.activeProcessingAlertTitle,
                message: HistoryFlowKind.transcribe.activeProcessingAlertMessage
            )
            return false
        }

        return true
    }
}

private extension TranscribeFlowViewModel {
    struct DecodedResult {
        let transcriptSegments: [TranscribeTranscriptSegment]
        let summaryTopics: [String]
    }
}

private struct FallbackFetchProfileUseCase: FetchProfileUseCase {
    func execute(userId: String) async throws -> BackendProfileData {
        BackendProfileData(userId: userId, availableGenerations: 2_000, isActivePlan: false)
    }
}

private struct FallbackAuthorizeUserUseCase: AuthorizeUserUseCase {
    func execute(userId: String, gender: String) async throws -> BackendAuthData {
        BackendAuthData(userId: userId, availableGenerations: 2_000, isActivePlan: false)
    }
}

private struct FallbackSetFreeGenerationsUseCase: SetFreeGenerationsUseCase {
    func execute(userId: String) async throws {}
}

private struct FallbackAddGenerationsUseCase: AddGenerationsUseCase {
    func execute(userId: String, productId: Int) async throws {}
}

private struct FallbackFetchServicePricesUseCase: FetchServicePricesUseCase {
    func execute(userId: String) async throws -> BackendServicePricesData {
        let fallbackPayload = #"{"transcribe":1}"#
        return try JSONDecoder().decode(
            BackendServicePricesData.self,
            from: Data(fallbackPayload.utf8)
        )
    }
}

private struct FallbackTranscribeUseCase: TranscribeUseCase {
    func execute(_ request: TranscribeRequest) async throws -> BackendTranscribeResult {
        try await resume(taskId: UUID().uuidString)
    }

    func start(_ request: TranscribeRequest) async throws -> BackendTranscribeStartData {
        BackendTranscribeStartData(taskId: UUID().uuidString)
    }

    func resume(taskId: String) async throws -> BackendTranscribeResult {
        let sample = #"{"summary":{"one_topic":"[\"Topic 1 description\",\"Topic 2 description\",\"Topic 3 description\"]"},"transcription":[{"text":"Welcome to today's discussion on artificial intelligence.","speaker":"SPEAKER_00","end":8.0,"start":0.0},{"text":"This is a sample transcript block.","speaker":"SPEAKER_00","end":14.0,"start":8.0}]}"#
        let rawData = Data(sample.utf8)
        return BackendTranscribeResult(
            taskId: taskId,
            status: "COMPLETED",
            resultJSONString: sample,
            rawResultData: rawData
        )
    }
}
