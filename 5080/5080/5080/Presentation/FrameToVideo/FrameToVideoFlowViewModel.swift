import Foundation
import Combine
import Adapty
import UIKit

@MainActor
final class FrameToVideoFlowViewModel: ObservableObject {
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

    let sceneViewModel: FrameToVideoSceneViewModel
    let loadingViewModel: TextToVideoLoadingSceneViewModel
    let failedViewModel: TextToVideoFailedSceneViewModel

    private let fetchProfileUseCase: FetchProfileUseCase
    private let authorizeUserUseCase: AuthorizeUserUseCase
    private let setFreeGenerationsUseCase: SetFreeGenerationsUseCase
    private let addGenerationsUseCase: AddGenerationsUseCase
    private let fetchServicePricesUseCase: FetchServicePricesUseCase
    private let frameToVideoUseCase: FrameToVideoUseCase
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

    nonisolated private static let maxUploadBytes = 300_000
    nonisolated private static let minImageDimension: CGFloat = 96
    private static let requestModelName = "kling-v1-6-pro"
    private static let requestMode = "std"

    init(
        sceneViewModel: FrameToVideoSceneViewModel,
        loadingViewModel: TextToVideoLoadingSceneViewModel,
        failedViewModel: TextToVideoFailedSceneViewModel,
        fetchProfileUseCase: FetchProfileUseCase,
        authorizeUserUseCase: AuthorizeUserUseCase,
        setFreeGenerationsUseCase: SetFreeGenerationsUseCase,
        addGenerationsUseCase: AddGenerationsUseCase,
        fetchServicePricesUseCase: FetchServicePricesUseCase,
        frameToVideoUseCase: FrameToVideoUseCase,
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
        self.frameToVideoUseCase = frameToVideoUseCase
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

    static var fallback: FrameToVideoFlowViewModel {
        FrameToVideoFlowViewModel(
            sceneViewModel: FrameToVideoSceneViewModel(),
            loadingViewModel: TextToVideoLoadingSceneViewModel(title: "Frame to Video"),
            failedViewModel: TextToVideoFailedSceneViewModel(title: "Frame to Video"),
            fetchProfileUseCase: FallbackFetchProfileUseCase(),
            authorizeUserUseCase: FallbackAuthorizeUserUseCase(),
            setFreeGenerationsUseCase: FallbackSetFreeGenerationsUseCase(),
            addGenerationsUseCase: FallbackAddGenerationsUseCase(),
            fetchServicePricesUseCase: FallbackFetchServicePricesUseCase(),
            frameToVideoUseCase: FallbackFrameToVideoUseCase(),
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

        guard let startFrameData = sceneViewModel.startFrameData else {
            sceneViewModel.showError("Please upload start frame")
            return
        }

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
                title: HistoryFlowKind.frameToVideo.activeProcessingAlertTitle,
                message: HistoryFlowKind.frameToVideo.activeProcessingAlertMessage
            )
            return
        }

        route = .loading
        let historyID = historyRepository.createProcessingEntry(
            flowKind: .frameToVideo,
            title: historyTitle(from: prompt, fallback: "Frame to Video"),
            prompt: prompt
        )
        currentHistoryEntryID = historyID

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let userId = await self.resolvedUserID()
                await self.ensureAuthorized(userId: userId)

                let pendingStartingRecord = PendingHistoryRecoveryRecord(
                    historyEntryId: historyID,
                    flowKind: .frameToVideo,
                    recoveryKind: .generation,
                    stage: .starting,
                    userId: userId
                )
                await self.pendingRecoveryStore.upsert(pendingStartingRecord)

                let request = FrameToVideoRequest(
                    userId: userId,
                    cfgScale: "0.5",
                    duration: self.sceneViewModel.selectedDuration.requestValue,
                    prompt: prompt,
                    modelName: Self.requestModelName,
                    mode: Self.requestMode,
                    startFrame: self.binaryUpload(from: startFrameData, prefix: "frame_start"),
                    endFrame: self.sceneViewModel.endFrameData.map {
                        self.binaryUpload(from: $0, prefix: "frame_end")
                    }
                )

                let resultPayload = try await self.executeGenerationWithFallback(
                    userId: userId,
                    request: request,
                    onJobAccepted: { jobId in
                        let pollingRecord = PendingHistoryRecoveryRecord(
                            historyEntryId: historyID,
                            flowKind: .frameToVideo,
                            recoveryKind: .generation,
                            stage: .polling,
                            userId: userId,
                            remoteIdentifier: jobId,
                            createdAt: pendingStartingRecord.createdAt
                        )
                        await self.pendingRecoveryStore.upsert(pollingRecord)
                    }
                )
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

    private func executeGenerationWithFallback(
        userId: String,
        request: FrameToVideoRequest,
        onJobAccepted: @escaping (String) async -> Void
    ) async throws -> BackendGenerationStatusPayload {
        let requests = retryRequests(from: request)
        var lastError: Error?

        for (index, candidate) in requests.enumerated() {
            do {
                let startPayload = try await frameToVideoUseCase.execute(candidate)
                try Task.checkCancellation()

                guard let jobId = startPayload.jobId,
                      !jobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw APIError.backendMessage("Generation job id is missing")
                }

                await onJobAccepted(jobId)
                return try await pollGenerationResult(userId: userId, jobId: jobId)
            } catch let error as CancellationError {
                throw error
            } catch {
                lastError = error

                let hasNext = index < requests.count - 1
                guard hasNext, shouldRetryGeneration(error) else {
                    throw error
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        throw lastError ?? APIError.backendMessage("Generation failed")
    }

    private func retryRequests(from request: FrameToVideoRequest) -> [FrameToVideoRequest] {
        var requests = [request, request]

        if request.endFrame != nil {
            requests.append(
                FrameToVideoRequest(
                    userId: request.userId,
                    cfgScale: request.cfgScale,
                    duration: request.duration,
                    prompt: request.prompt,
                    modelName: request.modelName,
                    mode: request.mode,
                    startFrame: request.startFrame,
                    endFrame: nil,
                    negativePrompt: request.negativePrompt
                )
            )
        }

        return requests
    }

    private func shouldRetryGeneration(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .timedOut,
                .networkConnectionLost,
                .cannotFindHost,
                .cannotConnectToHost,
                .dnsLookupFailed
            ].contains(urlError.code)
        }

        guard case let APIError.backendMessage(message) = error else {
            return false
        }

        let text = message.lowercased()
        return text.contains("generation status: error") ||
            text.contains("generation status: failed") ||
            text.contains("generation status: canceled") ||
            text.contains("generation status: cancelled") ||
            text.contains("generation timeout") ||
            text.contains("status payload is empty")
    }

    private func storeGeneratedVideo(_ data: Data) throws -> URL {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let folderURL = cachesDirectory.appendingPathComponent("FrameToVideo", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileURL = folderURL.appendingPathComponent("frame_to_video_\(UUID().uuidString).mp4")
        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }

    private func binaryUpload(from data: Data, prefix: String) -> BinaryUpload {
        let normalizedData = Self.normalizedUploadDataForTransport(from: data)
        #if DEBUG
        print("[Upload][FrameToVideo][\(prefix)] bytes=\(normalizedData.count)")
        #endif

        let isPNG = normalizedData.starts(with: [0x89, 0x50, 0x4E, 0x47])
        let fileExtension = isPNG ? "png" : "jpg"
        let mimeType = isPNG ? "image/png" : "image/jpeg"

        return BinaryUpload(
            data: normalizedData,
            fileName: "\(prefix)_\(UUID().uuidString).\(fileExtension)",
            mimeType: mimeType
        )
    }

    nonisolated private static func normalizedUploadDataForTransport(from originalData: Data) -> Data {
        guard originalData.count >= maxUploadBytes,
              let image = UIImage(data: originalData) else {
            return originalData
        }

        var currentImage = image
        for _ in 0..<12 {
            if let compressed = highestQualityJPEGUnderLimit(from: currentImage) {
                return compressed
            }
            guard let resized = downscaledImage(from: currentImage, factor: 0.82) else {
                break
            }
            currentImage = resized
        }

        if let low = currentImage.jpegData(compressionQuality: 0.01),
           low.count < maxUploadBytes {
            return low
        }

        return originalData
    }

    nonisolated private static func highestQualityJPEGUnderLimit(from image: UIImage) -> Data? {
        guard let minimum = image.jpegData(compressionQuality: 0.01),
              minimum.count < maxUploadBytes else {
            return nil
        }

        var best = minimum
        var low: CGFloat = 0.01
        var high: CGFloat = 1.0

        for _ in 0..<22 {
            let quality = (low + high) / 2.0
            guard let candidate = image.jpegData(compressionQuality: quality) else { continue }
            if candidate.count < maxUploadBytes {
                best = candidate
                low = quality
            } else {
                high = quality
            }
        }

        return best
    }

    nonisolated private static func downscaledImage(from image: UIImage, factor: CGFloat) -> UIImage? {
        let old = image.size
        let target = CGSize(
            width: max(minImageDimension, floor(old.width * factor)),
            height: max(minImageDimension, floor(old.height * factor))
        )
        guard target.width < old.width || target.height < old.height else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
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
            generationKind: .imageToVideo
        )

        let fallbackCost = max(
            1,
            durationPriceMap.values.min() ?? 0,
            prices.pricesByKey["klingFrame"] ??
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
        guard !historyRepository.hasProcessingEntry(flowKind: .frameToVideo) else {
            sceneViewModel.showAlert(
                title: HistoryFlowKind.frameToVideo.activeProcessingAlertTitle,
                message: HistoryFlowKind.frameToVideo.activeProcessingAlertMessage
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
        let fallbackPayload = #"{"klingFrame":2,"klingPriceModelDuration":[{"model":"kling-v1-6-pro","seconds":[{"duration":5,"price":11},{"duration":10,"price":15}]}],"klingPrice":[{"model":"kling16pro_img2video","seconds":[{"duration":5,"price":6},{"duration":10,"price":12}]}]}"#
        return try JSONDecoder().decode(
            BackendServicePricesData.self,
            from: Data(fallbackPayload.utf8)
        )
    }
}

private struct FallbackFrameToVideoUseCase: FrameToVideoUseCase {
    func execute(_ request: FrameToVideoRequest) async throws -> BackendGenerationStartData {
        BackendGenerationStartData(jobId: UUID().uuidString, status: "PENDING")
    }
}

private struct FallbackGenerationStatusUseCase: GenerationStatusUseCase {
    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        let data = Data()
        return BackendGenerationStatusPayload(isVideo: true, resultData: data, previewData: nil)
    }
}
