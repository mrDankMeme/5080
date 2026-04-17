import Foundation
import Combine
import Adapty

@MainActor
final class AIImageFlowViewModel: ObservableObject {
    enum Route {
        case composer
        case loading
        case result
        case failed
    }

    @Published private(set) var route: Route = .composer
    @Published private(set) var resultViewModel: AIImageResultSceneViewModel?
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var isSubscriptionPaywallPresented = false
    @Published private(set) var isTokensPaywallPresented = false

    let sceneViewModel: AIImageSceneViewModel
    let loadingViewModel: TextToVideoLoadingSceneViewModel
    let failedViewModel: TextToVideoFailedSceneViewModel

    private let fetchProfileUseCase: FetchProfileUseCase
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchServicePricesUseCase: FetchServicePricesUseCase
    private let generateAIImageUseCase: GenerateAIImageUseCase
    private let generationStatusUseCase: GenerationStatusUseCase
    private let historyRepository: HistoryRepository
    private let pendingRecoveryStore: PendingHistoryRecoveryStore
    private let purchaseManager: PurchaseManager
    private let billingAccessResolver: BillingAccessResolving
    private let aiProcessingConsentManager: AIProcessingConsentManaging
    private let resultViewModelFactory: (URL) -> AIImageResultSceneViewModel

    private var generationTask: Task<Void, Never>?
    private var didLoadProfile = false
    private var currentHistoryEntryID: UUID?
    private var cancellables = Set<AnyCancellable>()

    init(
        sceneViewModel: AIImageSceneViewModel,
        loadingViewModel: TextToVideoLoadingSceneViewModel,
        failedViewModel: TextToVideoFailedSceneViewModel,
        fetchProfileUseCase: FetchProfileUseCase,
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchServicePricesUseCase: FetchServicePricesUseCase,
        generateAIImageUseCase: GenerateAIImageUseCase,
        generationStatusUseCase: GenerationStatusUseCase,
        historyRepository: HistoryRepository,
        pendingRecoveryStore: PendingHistoryRecoveryStore,
        purchaseManager: PurchaseManager,
        billingAccessResolver: BillingAccessResolving,
        aiProcessingConsentManager: AIProcessingConsentManaging,
        resultViewModelFactory: @escaping (URL) -> AIImageResultSceneViewModel
    ) {
        self.sceneViewModel = sceneViewModel
        self.loadingViewModel = loadingViewModel
        self.failedViewModel = failedViewModel
        self.fetchProfileUseCase = fetchProfileUseCase
        self.authorizeUserUseCase = authorizeUserUseCase
        self.setFreeGenerationsUseCase = setFreeGenerationsUseCase
        self.addGenerationsUseCase = addGenerationsUseCase
        self.fetchServicePricesUseCase = fetchServicePricesUseCase
        self.generateAIImageUseCase = generateAIImageUseCase
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

    static var fallback: AIImageFlowViewModel {
        AIImageFlowViewModel(
            sceneViewModel: AIImageSceneViewModel(),
            loadingViewModel: TextToVideoLoadingSceneViewModel(title: "AI Image"),
            failedViewModel: TextToVideoFailedSceneViewModel(
                title: "AI Image",
                subtitle: "We couldn't create your image. Don't worry, your tokens have not been deducted."
            ),
            fetchProfileUseCase: FallbackFetchProfileUseCase(),
            authorizeUserUseCase: FallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: FallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: FallbackAddGenerationsUseCase(),
            fetchServicePricesUseCase: FallbackFetchServicePricesUseCase(),
            generateAIImageUseCase: FallbackGenerateAIImageUseCase(),
            generationStatusUseCase: FallbackGenerationStatusUseCase(),
            historyRepository: InMemoryHistoryRepository(),
            pendingRecoveryStore: PendingHistoryRecoveryFileStore(),
            purchaseManager: PurchaseManager.shared,
            billingAccessResolver: DefaultBillingAccessResolver(
                purchaseManager: PurchaseManager.shared
            ),
            aiProcessingConsentManager: UserDefaultsAIProcessingConsentManager(userDefaults: .standard),
            resultViewModelFactory: { imageURL in
                AIImageResultSceneViewModel(imageURL: imageURL)
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
                title: HistoryFlowKind.aiImage.activeProcessingAlertTitle,
                message: HistoryFlowKind.aiImage.activeProcessingAlertMessage
            )
            return
        }

        route = .loading
        let historyID = historyRepository.createProcessingEntry(
            flowKind: .aiImage,
            title: historyTitle(from: prompt, fallback: "AI Image"),
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
                    flowKind: .aiImage,
                    recoveryKind: .generation,
                    stage: .starting,
                    userId: userId
                )
                await self.pendingRecoveryStore.upsert(pendingRecord)

                let payloadData = try self.buildRequestPayloadData(userId: userId, prompt: prompt)
                let request = AIImageRequest(payloadData: payloadData)

                let startPayload = try await self.generateAIImageUseCase.execute(request)
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
                let localImageURL = try self.storeGeneratedImage(resultPayload.resultData)

                let vm = self.resultViewModelFactory(localImageURL)
                self.resultViewModel = vm

                await self.syncBalanceAfterGeneration(userId: userId)
                await self.pendingRecoveryStore.remove(historyEntryId: historyID)
                if let historyID = self.currentHistoryEntryID {
                    self.historyRepository.markEntryReady(
                        id: historyID,
                        mediaLocalURL: localImageURL,
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

    private func buildRequestPayloadData(userId: String, prompt: String) throws -> Data {
        // Sora text2image is currently stable only for 9:16 + auto in production.
        let forcedAspectRatio = AIImageSceneViewModel.AspectRatio.ratio9x16
        let forcedQuality = AIImageSceneViewModel.Quality.auto

        sceneViewModel.selectedAspectRatio = forcedAspectRatio
        sceneViewModel.selectedQuality = forcedQuality

        var payload: [String: Any] = [
            "userId": userId,
            "prompt": prompt,
            "quality": forcedQuality.requestValue,
            "aspectRatio": forcedAspectRatio.rawValue
        ]

        payload["size"] = forcedAspectRatio.sizeValue ?? "1024x1536"

        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func pollGenerationResult(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let maxAttempts = 1_050
        let pollingIntervalNanoseconds: UInt64 = 2_000_000_000

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

    private func storeGeneratedImage(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let folderURL = cachesDirectory.appendingPathComponent("AIImage", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileExtension = detectImageFileExtension(data)
        let fileURL = folderURL.appendingPathComponent("ai_image_\(UUID().uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    private func detectImageFileExtension(_ data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if data.count >= 12 {
            let riffHeader = String(data: data.prefix(4), encoding: .ascii)
            let webpMarker = String(data: data.subdata(in: 8..<12), encoding: .ascii)
            if riffHeader == "RIFF", webpMarker == "WEBP" {
                return "webp"
            }
        }

        return "png"
    }

    private func resolvedUserID() async -> String {
        if let adaptyProfileId = await fetchAdaptyProfileIDWithRetry() {
            purchaseManager.userId = adaptyProfileId
            return adaptyProfileId
        }

        let fromBilling = purchaseManager.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromBilling.isEmpty {
            return fromBilling
        }

        let key = "backend_shared_user_id"
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            purchaseManager.userId = existing
            return existing
        }

        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        purchaseManager.userId = generated
        return generated
    }

    private func fetchAdaptyProfileIDWithRetry() async -> String? {
        let maxAttempts = 6
        for attempt in 0..<maxAttempts {
            guard !Task.isCancelled else { return nil }

            if let id = await fetchAdaptyProfileID() {
                return id
            }

            guard attempt < maxAttempts - 1 else { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
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

    private func fetchAdaptyProfileID() async -> String? {
        do {
            let profile = try await Adapty.getProfile()
            let id = profile.profileId.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        } catch {
            return nil
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
        if isTerminalGenerationStatusMessage(text) {
            return false
        }

        if let status = parsedGenerationStatus(from: text) {
            return pendingGenerationStatuses.contains(status)
        }

        return pendingGenerationStatuses.contains { text.contains($0) }
    }

    private func parsedGenerationStatus(from message: String) -> String? {
        let marker = "generation status:"
        guard let range = message.range(of: marker) else { return nil }

        let rawStatus = message[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawStatus.isEmpty else { return nil }

        let token = rawStatus
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let token, !token.isEmpty else { return nil }
        return token
    }

    private func isTerminalGenerationStatusMessage(_ message: String) -> Bool {
        return message.contains("generation status: error") ||
            message.contains("generation status: failed") ||
            message.contains("generation status: canceled") ||
            message.contains("generation status: cancelled") ||
            message.contains("generation status: expired")
    }

    private var pendingGenerationStatuses: Set<String> {
        [
            "new",
            "in_progress",
            "in progress",
            "pending",
            "processing",
            "queued",
            "working",
            "starting",
            "running"
        ]
    }

    private func applyGeneratePricing(_ prices: BackendServicePricesData) {
        let resolvedCost = max(
            1,
            prices.pricesByKey["txt2img"] ??
            prices.pricesByKey["generate"] ??
            1
        )

        sceneViewModel.updateGenerateCost(resolvedCost)
    }

    private func historyTitle(from prompt: String, fallback: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(80))
    }

    private func canStartAnotherGeneration() -> Bool {
        guard !historyRepository.hasProcessingEntry(flowKind: .aiImage) else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.aiImage.activeProcessingAlertTitle,
                message: HistoryFlowKind.aiImage.activeProcessingAlertMessage
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
        let fallbackPayload = #"{"txt2img":1,"generate":1}"#
        return try JSONDecoder().decode(
            BackendServicePricesData.self,
            from: Data(fallbackPayload.utf8)
        )
    }
}

private struct FallbackGenerateAIImageUseCase: GenerateAIImageUseCase {
    func execute(_ request: AIImageRequest) async throws -> BackendGenerationStartData {
        BackendGenerationStartData(jobId: UUID().uuidString, status: "PENDING")
    }
}

private struct FallbackGenerationStatusUseCase: GenerationStatusUseCase {
    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let data = Data()
        return BackendGenerationStatusPayload(isVideo: false, resultData: data, previewData: nil)
    }
}
