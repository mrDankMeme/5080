import Foundation
import Combine

@MainActor
final class VoiceGenFlowViewModel: ObservableObject {
    enum Route {
        case composer
        case loading
        case result
        case failed
    }

    @Published private(set) var route: Route = .composer
    @Published private(set) var resultViewModel: VoiceGenResultSceneViewModel?
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let sceneViewModel: VoiceGenSceneViewModel
    let loadingViewModel: TextToVideoLoadingSceneViewModel
    let failedViewModel: TextToVideoFailedSceneViewModel

    private let fetchProfileUseCase: FetchProfileUseCase
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchServicePricesUseCase: FetchServicePricesUseCase
    private let voiceGenUseCase: VoiceGenUseCase
    private let generationStatusUseCase: GenerationStatusUseCase
    private let historyRepository: HistoryRepository
    private let pendingRecoveryStore: PendingHistoryRecoveryStore
    private let purchaseManager: PurchaseManager
    private let billingAccessResolver: BillingAccessResolving
    private let aiProcessingConsentManager: AIProcessingConsentManaging
    private let resultViewModelFactory: (URL, String) -> VoiceGenResultSceneViewModel

    private var generationTask: Task<Void, Never>?
    private var didLoadProfile = false
    private var currentHistoryEntryID: UUID?
    private var cancellables = Set<AnyCancellable>()

    init(
        sceneViewModel: VoiceGenSceneViewModel,
        loadingViewModel: TextToVideoLoadingSceneViewModel,
        failedViewModel: TextToVideoFailedSceneViewModel,
        fetchProfileUseCase: FetchProfileUseCase,
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchServicePricesUseCase: FetchServicePricesUseCase,
        voiceGenUseCase: VoiceGenUseCase,
        generationStatusUseCase: GenerationStatusUseCase,
        historyRepository: HistoryRepository,
        pendingRecoveryStore: PendingHistoryRecoveryStore,
        purchaseManager: PurchaseManager,
        billingAccessResolver: BillingAccessResolving,
        aiProcessingConsentManager: AIProcessingConsentManaging,
        resultViewModelFactory: @escaping (URL, String) -> VoiceGenResultSceneViewModel
    ) {
        self.sceneViewModel = sceneViewModel
        self.loadingViewModel = loadingViewModel
        self.failedViewModel = failedViewModel
        self.fetchProfileUseCase = fetchProfileUseCase
        self.authorizeUserUseCase = authorizeUserUseCase
        self.setFreeGenerationsUseCase = setFreeGenerationsUseCase
        self.addGenerationsUseCase = addGenerationsUseCase
        self.fetchServicePricesUseCase = fetchServicePricesUseCase
        self.voiceGenUseCase = voiceGenUseCase
        self.generationStatusUseCase = generationStatusUseCase
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

    static var fallback: VoiceGenFlowViewModel {
        VoiceGenFlowViewModel(
            sceneViewModel: VoiceGenSceneViewModel(),
            loadingViewModel: TextToVideoLoadingSceneViewModel(
                title: "Voice Gen",
                heading: "Generating voiceover...",
                subtitle: "Please wait, it won't take long"
            ),
            failedViewModel: TextToVideoFailedSceneViewModel(
                title: "Voice Gen",
                subtitle: "We couldn't create your voiceover. Don't worry, your tokens have not been deducted."
            ),
            fetchProfileUseCase: FallbackFetchProfileUseCase(),
            authorizeUserUseCase: FallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: FallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: FallbackAddGenerationsUseCase(),
            fetchServicePricesUseCase: FallbackFetchServicePricesUseCase(),
            voiceGenUseCase: FallbackVoiceGenUseCase(),
            generationStatusUseCase: FallbackGenerationStatusUseCase(),
            historyRepository: InMemoryHistoryRepository(),
            pendingRecoveryStore: PendingHistoryRecoveryFileStore(),
            purchaseManager: PurchaseManager.shared,
            billingAccessResolver: DefaultBillingAccessResolver(
                purchaseManager: PurchaseManager.shared
            ),
            aiProcessingConsentManager: UserDefaultsAIProcessingConsentManager(userDefaults: .standard),
            resultViewModelFactory: { url, title in
                VoiceGenResultSceneViewModel(audioURL: url, displayTitle: title)
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

    func startGeneration() {
        sceneViewModel.clearError()

        let baseScript = sceneViewModel.effectiveScriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseScript.isEmpty else {
            sceneViewModel.showError("Please enter a script")
            return
        }

        guard canStartAnotherGeneration() else {
            return
        }

        if let paywallDestination = billingAccessResolver.destinationForGeneration(
            requiredTokens: sceneViewModel.generateCost
        ) {
            presentPaywall(paywallDestination)
            return
        }

        guard generationTask == nil else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.voiceGen.activeProcessingAlertTitle,
                message: HistoryFlowKind.voiceGen.activeProcessingAlertMessage
            )
            return
        }

        route = .loading
        let historyID = historyRepository.createProcessingEntry(
            flowKind: .voiceGen,
            title: historyTitle(from: baseScript, fallback: "Voice Gen"),
            prompt: baseScript
        )
        currentHistoryEntryID = historyID

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let userId = await self.resolvedUserID()
                await self.ensureAuthorized(userId: userId)

                var pendingRecord = PendingHistoryRecoveryRecord(
                    historyEntryId: historyID,
                    flowKind: .voiceGen,
                    recoveryKind: .generation,
                    stage: .starting,
                    userId: userId
                )
                await self.pendingRecoveryStore.upsert(pendingRecord)

                let prompt = self.sceneViewModel.makePromptForRequest()
                let payloadData = try self.buildVoicePayloadData(userId: userId, prompt: prompt)

                let startPayload = try await self.voiceGenUseCase.execute(
                    VoiceGenRequest(payloadData: payloadData)
                )
                try Task.checkCancellation()

                guard let jobId = startPayload.jobId,
                      !jobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw APIError.backendMessage("Generation job id is missing")
                }

                pendingRecord.stage = .polling
                pendingRecord.remoteIdentifier = jobId
                pendingRecord.updatedAt = Date()
                await self.pendingRecoveryStore.upsert(pendingRecord)

                let resultPayload = try await self.pollGenerationResult(userId: userId, jobId: jobId)
                let localAudioURL = try self.storeGeneratedAudio(resultPayload.resultData)
                let resultTitle = self.makeResultTitle(from: baseScript)

                let vm = self.resultViewModelFactory(localAudioURL, resultTitle)
                self.resultViewModel = vm

                await self.syncBalanceAfterGeneration(userId: userId)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryReady(
                        id: historyID,
                        mediaLocalURL: localAudioURL,
                        transcribePayload: nil
                    )
                }
                self.currentHistoryEntryID = nil

                self.route = .result
            } catch is CancellationError {
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.deleteEntry(id: historyID)
                    self.currentHistoryEntryID = nil
                }
                self.route = .composer
            } catch {
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryFailed(id: historyID)
                    self.currentHistoryEntryID = nil
                }
                self.route = .failed
            }

            self.generationTask = nil
        }
    }

    func cancelLoading() {
        generationTask?.cancel()
        generationTask = nil
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
        startGeneration()
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
            applyGeneratePricing(prices)
        } catch {
            sceneViewModel.updateGenerateCost(1)
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

    private func buildVoicePayloadData(userId: String, prompt: String) throws -> Data {
        let stylePrompt = "Voiceover narration, \(sceneViewModel.selectedVoiceSkin.requestValue) voice, \(sceneViewModel.selectedTone.requestValue) tone, speed \(sceneViewModel.selectedSpeed.requestValue)x"

        let payload: [String: Any] = [
            "userId": userId,
            "prompt": prompt,
            "lyricsPrompt": stylePrompt,
            "customId": "voice_\(UUID().uuidString.prefix(8))"
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func pollGenerationResult(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let maxAttempts = 1_050
        let pollingIntervalNanoseconds: UInt64 = 3_000_000_000

        for attempt in 0..<maxAttempts {
            try Task.checkCancellation()

            do {
                return try await generationStatusUseCase.execute(userId: userId, jobId: jobId)
            } catch {
                guard isPendingStatusError(error), attempt < maxAttempts - 1 else {
                    throw error
                }

                try await Task.sleep(nanoseconds: pollingIntervalNanoseconds)
            }
        }

        throw APIError.backendMessage("Generation timeout")
    }

    private func storeGeneratedAudio(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let folderURL = cachesDirectory.appendingPathComponent("VoiceGen", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileExtension = detectAudioFileExtension(data)
        let fileURL = folderURL.appendingPathComponent("voice_gen_\(UUID().uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    private func detectAudioFileExtension(_ data: Data) -> String {
        if data.starts(with: [0x49, 0x44, 0x33]) {
            return "mp3"
        }

        if data.count >= 12 {
            let riffHeader = String(data: data.prefix(4), encoding: .ascii)
            let waveMarker = String(data: data.subdata(in: 8..<12), encoding: .ascii)
            if riffHeader == "RIFF", waveMarker == "WAVE" {
                return "wav"
            }

            let ftypChunk = String(data: data.subdata(in: 4..<12), encoding: .ascii) ?? ""
            if ftypChunk.contains("ftyp") {
                return "m4a"
            }
        }

        return "mp3"
    }

    private func makeResultTitle(from script: String) -> String {
        let compact = script
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else {
            return "Voiceover"
        }

        return String(compact.prefix(36))
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
        guard sceneViewModel.availableTokens < sceneViewModel.generateCost else { return }

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

        if sceneViewModel.availableTokens < sceneViewModel.generateCost,
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

    private func isPendingStatusError(_ error: Error) -> Bool {
        if case let APIError.backendMessage(message) = error {
            return isPendingStatusMessage(message)
        }

        let text = error.localizedDescription
        return isPendingStatusMessage(text)
    }

    private func isPendingStatusMessage(_ message: String) -> Bool {
        let text = message.lowercased()
        return text.contains("generation status") ||
            text.contains("new") ||
            text.contains("in_progress") ||
            text.contains("in progress") ||
            text.contains("pending") ||
            text.contains("processing") ||
            text.contains("queued") ||
            text.contains("working") ||
            text.contains("starting") ||
            text.contains("running")
    }

    private func applyGeneratePricing(_ prices: BackendServicePricesData) {
        let cost = max(
            1,
            prices.pricesByKey["minimax15"] ??
            prices.pricesByKey["generate"] ??
            1
        )
        sceneViewModel.updateGenerateCost(cost)
    }

    private func historyTitle(from prompt: String, fallback: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(80))
    }

    private func canStartAnotherGeneration() -> Bool {
        guard !historyRepository.hasProcessingEntry(flowKind: .voiceGen) else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.voiceGen.activeProcessingAlertTitle,
                message: HistoryFlowKind.voiceGen.activeProcessingAlertMessage
            )
            return false
        }

        return true
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
        let fallbackPayload = #"{"minimax15":5}"#
        return try JSONDecoder().decode(
            BackendServicePricesData.self,
            from: Data(fallbackPayload.utf8)
        )
    }
}

private struct FallbackVoiceGenUseCase: VoiceGenUseCase {
    func execute(_ request: VoiceGenRequest) async throws -> BackendGenerationStartData {
        BackendGenerationStartData(jobId: UUID().uuidString, status: "PENDING")
    }
}

private struct FallbackGenerationStatusUseCase: GenerationStatusUseCase {
    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let data = Data()
        return BackendGenerationStatusPayload(isVideo: false, resultData: data, previewData: nil)
    }
}
