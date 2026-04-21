import Foundation
import Combine

@MainActor
final class TextToVideoFlowViewModel: ObservableObject {
    enum Route {
        case composer
        case loading
        case result
        case failed
    }

    @Published private(set) var route: Route = .composer
    @Published private(set) var resultViewModel: TextToVideoResultSceneViewModel?
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let sceneViewModel: TextToVideoSceneViewModel
    let loadingViewModel: TextToVideoLoadingSceneViewModel
    let failedViewModel: TextToVideoFailedSceneViewModel

    private let fetchProfileUseCase: FetchProfileUseCase
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchServicePricesUseCase: FetchServicePricesUseCase
    private let generateTextToVideoUseCase: GenerateTextToVideoUseCase
    private let generationStatusUseCase: GenerationStatusUseCase
    private let historyRepository: HistoryRepository
    private let pendingRecoveryStore: PendingHistoryRecoveryStore
    private let purchaseManager: PurchaseManager
    private let billingAccessResolver: BillingAccessResolving
    private let aiProcessingConsentManager: AIProcessingConsentManaging
    private let resultViewModelFactory: (URL) -> TextToVideoResultSceneViewModel

    private var generationTask: Task<Void, Never>?
    private var didLoadProfile = false
    private var currentHistoryEntryID: UUID?
    private var cancellables = Set<AnyCancellable>()

    private static let requestModelName = "kling-v1-6"
    private static let requestMode = "std"

    init(
        sceneViewModel: TextToVideoSceneViewModel,
        loadingViewModel: TextToVideoLoadingSceneViewModel,
        failedViewModel: TextToVideoFailedSceneViewModel,
        fetchProfileUseCase: FetchProfileUseCase,
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchServicePricesUseCase: FetchServicePricesUseCase,
        generateTextToVideoUseCase: GenerateTextToVideoUseCase,
        generationStatusUseCase: GenerationStatusUseCase,
        historyRepository: HistoryRepository,
        pendingRecoveryStore: PendingHistoryRecoveryStore,
        purchaseManager: PurchaseManager,
        billingAccessResolver: BillingAccessResolving,
        aiProcessingConsentManager: AIProcessingConsentManaging,
        resultViewModelFactory: @escaping (URL) -> TextToVideoResultSceneViewModel
    ) {
        self.sceneViewModel = sceneViewModel
        self.loadingViewModel = loadingViewModel
        self.failedViewModel = failedViewModel
        self.fetchProfileUseCase = fetchProfileUseCase
        self.authorizeUserUseCase = authorizeUserUseCase
        self.setFreeGenerationsUseCase = setFreeGenerationsUseCase
        self.addGenerationsUseCase = addGenerationsUseCase
        self.fetchServicePricesUseCase = fetchServicePricesUseCase
        self.generateTextToVideoUseCase = generateTextToVideoUseCase
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

    static var fallback: TextToVideoFlowViewModel {
        TextToVideoFlowViewModel(
            sceneViewModel: TextToVideoSceneViewModel(),
            loadingViewModel: TextToVideoLoadingSceneViewModel(),
            failedViewModel: TextToVideoFailedSceneViewModel(),
            fetchProfileUseCase: FallbackFetchProfileUseCase(),
            authorizeUserUseCase: FallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: FallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: FallbackAddGenerationsUseCase(),
            fetchServicePricesUseCase: FallbackFetchServicePricesUseCase(),
            generateTextToVideoUseCase: FallbackGenerateTextToVideoUseCase(),
            generationStatusUseCase: FallbackGenerationStatusUseCase(),
            historyRepository: InMemoryHistoryRepository(),
            pendingRecoveryStore: PendingHistoryRecoveryFileStore(),
            purchaseManager: PurchaseManager.shared,
            billingAccessResolver: DefaultBillingAccessResolver(
                purchaseManager: PurchaseManager.shared
            ),
            aiProcessingConsentManager: UserDefaultsAIProcessingConsentManager(userDefaults: .standard),
            resultViewModelFactory: { url in
                TextToVideoResultSceneViewModel(videoURL: url)
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

    func applyLaunchPrompt(_ prompt: String?) {
        guard let prompt else { return }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        sceneViewModel.clearError()
        sceneViewModel.setPrompt(trimmedPrompt)
        route = .composer
    }

    func startGeneration() {
        sceneViewModel.clearError()

        let prompt = sceneViewModel.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            sceneViewModel.showError("Please enter a prompt")
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
                title: HistoryFlowKind.textToVideo.activeProcessingAlertTitle,
                message: HistoryFlowKind.textToVideo.activeProcessingAlertMessage
            )
            return
        }

        route = .loading
        let historyID = historyRepository.createProcessingEntry(
            flowKind: .textToVideo,
            title: historyTitle(from: prompt, fallback: "Text to Video"),
            prompt: prompt
        )
        currentHistoryEntryID = historyID

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let userId = await self.resolvedUserID()
                await self.ensureAuthorized(userId: userId)

                var pendingRecord = PendingHistoryRecoveryRecord(
                    historyEntryId: historyID,
                    flowKind: .textToVideo,
                    recoveryKind: .generation,
                    stage: .starting,
                    userId: userId
                )
                await self.pendingRecoveryStore.upsert(pendingRecord)

                let request = TextToVideoRequest(
                    userId: userId,
                    cfgScale: "0.5",
                    duration: self.sceneViewModel.selectedDuration.requestValue,
                    aspectRatio: self.sceneViewModel.selectedAspectRatio.rawValue,
                    prompt: prompt,
                    modelName: Self.requestModelName,
                    mode: Self.requestMode
                )

                let startPayload = try await self.generateTextToVideoUseCase.execute(request)
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
                let localVideoURL = try self.storeGeneratedVideo(resultPayload.resultData)

                let vm = self.resultViewModelFactory(localVideoURL)
                self.resultViewModel = vm

                await self.syncBalanceAfterGeneration(userId: userId)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryReady(
                        id: historyID,
                        mediaLocalURL: localVideoURL,
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
            sceneViewModel.updateGeneratePricing(durationPriceMap: [:], fallbackCost: 1)
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

    private func storeGeneratedVideo(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let folderURL = cachesDirectory.appendingPathComponent("TextToVideo", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileURL = folderURL.appendingPathComponent("text_to_video_\(UUID().uuidString).mp4")
        try data.write(to: fileURL, options: .atomic)

        return fileURL
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
        return text.contains("in_progress") ||
            text.contains("in progress") ||
            text.contains("pending") ||
            text.contains("processing") ||
            text.contains("queued") ||
            text.contains("working") ||
            text.contains("starting") ||
            text.contains("running")
    }

    private func applyGeneratePricing(_ prices: BackendServicePricesData) {
        let durationPriceMap = prices.klingDurationPriceMap(
            requestModelName: Self.requestModelName,
            mode: Self.requestMode,
            generationKind: .textToVideo
        )

        let fallbackCost = max(
            1,
            durationPriceMap.values.min() ?? 0,
            prices.pricesByKey["klingTxt2vid"] ??
            prices.pricesByKey["generate"] ??
            1
        )

        sceneViewModel.updateGeneratePricing(
            durationPriceMap: durationPriceMap,
            fallbackCost: fallbackCost
        )
    }

    private func historyTitle(from prompt: String, fallback: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(80))
    }

    private func canStartAnotherGeneration() -> Bool {
        guard !historyRepository.hasProcessingEntry(flowKind: .textToVideo) else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.textToVideo.activeProcessingAlertTitle,
                message: HistoryFlowKind.textToVideo.activeProcessingAlertMessage
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
        let fallbackPayload = #"{"klingTxt2vid":2,"klingPriceModelDuration":[{"model":"kling-v1-6","seconds":[{"duration":5,"price":10},{"duration":10,"price":14}]}],"klingPrice":[{"model":"kling16std_txt2video","seconds":[{"duration":5,"price":3},{"duration":10,"price":6}]}]}"#
        return try JSONDecoder().decode(
            BackendServicePricesData.self,
            from: Data(fallbackPayload.utf8)
        )
    }
}

private struct FallbackGenerateTextToVideoUseCase: GenerateTextToVideoUseCase {
    func execute(_ request: TextToVideoRequest) async throws -> BackendGenerationStartData {
        BackendGenerationStartData(jobId: UUID().uuidString, status: "PENDING")
    }
}

private struct FallbackGenerationStatusUseCase: GenerationStatusUseCase {
    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let data = Data()
        return BackendGenerationStatusPayload(isVideo: true, resultData: data, previewData: nil)
    }
}
