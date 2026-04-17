import Foundation
import Swinject
import Combine

protocol AIProcessingConsentManaging: AnyObject {
    var hasAcceptedConsent: Bool { get }
    func acceptConsent()
}

final class UserDefaultsAIProcessingConsentManager: AIProcessingConsentManaging {
    private let userDefaults: UserDefaults

    private static let consentKey = "ai_processing_consent_accepted"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var hasAcceptedConsent: Bool {
        userDefaults.bool(forKey: Self.consentKey)
    }

    func acceptConsent() {
        userDefaults.set(true, forKey: Self.consentKey)
    }
}

enum AIProcessingConsentAlertContent {
    static let title = "Consent for AI Processing"
    static let message = """
    To generate the requested result, the app will send the data you choose to our secure server:

    \u{2022} your text prompt;
    \u{2022} the image you upload, if you use generation based on a user image and text.

    This data is used only to fulfill your request and is not used to train or fine-tune our models. We do not sell or share this data with third parties for advertising purposes.

    By tapping "Agree", you consent to this processing.
    """
    static let agreeButtonTitle = "Agree"
    static let cancelButtonTitle = "Cancel"
}

final class ServicesAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIConfig.self) { _ in
            APIConfig(
                baseURL: URL(string: MiniMaxBackendDefaults.baseURLString)!,
                bearerToken: MiniMaxBackendDefaults.bearerToken
            )
        }
        .inObjectScope(.container)

        container.register(HTTPClient.self) { _ in
            URLSessionHTTPClient()
        }
        .inObjectScope(.container)

        container.register(MiniMaxBackendService.self) { r in
            MiniMaxBackendServiceImpl(
                config: r.resolve(APIConfig.self)!,
                http: r.resolve(HTTPClient.self)!
            )
        }
        .inObjectScope(.container)

        container.register(TranscribeAPIConfig.self) { _ in
            TranscribeAPIConfig(
                baseURL: URL(string: TranscribeBackendDefaults.baseURLString)!,
                apiKey: TranscribeBackendDefaults.apiKey
            )
        }
        .inObjectScope(.container)

        container.register(TranscribeBackendService.self) { r in
            TranscribeBackendServiceImpl(
                config: r.resolve(TranscribeAPIConfig.self)!,
                http: r.resolve(HTTPClient.self)!
            )
        }
        .inObjectScope(.container)

        container.register(AuthorizeUserUseCase.self) { r in
            DefaultAuthorizeUserUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(FetchProfileUseCase.self) { r in
            DefaultFetchProfileUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(SetFreeGenerationsUseCase.self) { r in
            DefaultSetFreeGenerationsUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(AddGenerationsUseCase.self) { r in
            DefaultAddGenerationsUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(CollectTokensUseCase.self) { r in
            DefaultCollectTokensUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(FetchAvailableBonusesUseCase.self) { r in
            DefaultFetchAvailableBonusesUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(FetchServicePricesUseCase.self) { r in
            DefaultFetchServicePricesUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(GenerateTextToVideoUseCase.self) { r in
            DefaultGenerateTextToVideoUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(AnimateImageUseCase.self) { r in
            DefaultAnimateImageUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(FrameToVideoUseCase.self) { r in
            DefaultFrameToVideoUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(VoiceGenUseCase.self) { r in
            DefaultVoiceGenUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(TranscribeUseCase.self) { r in
            DefaultTranscribeUseCase(service: r.resolve(TranscribeBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(GenerateAIImageUseCase.self) { r in
            DefaultGenerateAIImageUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(GenerationStatusUseCase.self) { r in
            DefaultGenerationStatusUseCase(service: r.resolve(MiniMaxBackendService.self)!)
        }
        .inObjectScope(.transient)

        container.register(PurchaseManager.self) { _ in
            MainActor.assumeIsolated { PurchaseManager.shared }
        }
        .inObjectScope(.container)

        container.register(BillingAccessResolving.self) { r in
            DefaultBillingAccessResolver(
                purchaseManager: r.resolve(PurchaseManager.self)!
            )
        }
        .inObjectScope(.container)

        container.register(AIProcessingConsentManaging.self) { _ in
            UserDefaultsAIProcessingConsentManager(userDefaults: .standard)
        }
        .inObjectScope(.container)

        container.register(HistoryRepository.self) { _ in
            DefaultHistoryRepository()
        }
        .inObjectScope(.container)

        container.register(PendingHistoryRecoveryStore.self) { _ in
            PendingHistoryRecoveryFileStore()
        }
        .inObjectScope(.container)

        container.register(PendingHistoryRecoveryRunner.self) { r in
            PendingHistoryRecoveryRunner(
                store: r.resolve(PendingHistoryRecoveryStore.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                transcribeUseCase: r.resolve(TranscribeUseCase.self)!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!
            )
        }
        .inObjectScope(.container)

        container.register(SupportMailComposerBuilding.self) { _ in
            DefaultSupportMailComposerBuilder(
                bundle: .main,
                supportEmail: AppExternalResources.supportEmail
            )
        }
        .inObjectScope(.container)

        container.register(RateUsScheduler.self) { _ in
            RateUsScheduler()
        }
        .inObjectScope(.container)

        container.register(OnboardingNotificationsScheduling.self) { _ in
            WeeklyOnboardingNotificationsScheduler()
        }
        .inObjectScope(.container)

        container.register(OnboardingViewModel.self) { r in
            OnboardingViewModel(
                notificationsScheduler: r.resolve(OnboardingNotificationsScheduling.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(SiteMakerAuthorizationProviding.self) { _ in
            SiteMakerAuthorizationProvider()
        }
        .inObjectScope(.container)

        container.register(SiteMakerRemoteServicing.self) { _ in
            SiteMakerRemoteService()
        }
        .inObjectScope(.container)

        container.register(SiteMakerRepositoryProtocol.self) { r in
            DefaultSiteMakerRepository(
                authorizationProvider: r.resolve(SiteMakerAuthorizationProviding.self)!,
                remoteService: r.resolve(SiteMakerRemoteServicing.self)!
            )
        }
        .inObjectScope(.container)

        container.register(FetchSiteMakerProjectsUseCaseProtocol.self) { r in
            DefaultFetchSiteMakerProjectsUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(CreateSiteMakerProjectUseCaseProtocol.self) { r in
            DefaultCreateSiteMakerProjectUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(FetchSiteMakerProjectUseCaseProtocol.self) { r in
            DefaultFetchSiteMakerProjectUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(UploadSiteMakerAssetUseCaseProtocol.self) { r in
            DefaultUploadSiteMakerAssetUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(ClarifySiteMakerProjectUseCaseProtocol.self) { r in
            DefaultClarifySiteMakerProjectUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(GenerateSiteMakerProjectUseCaseProtocol.self) { r in
            DefaultGenerateSiteMakerProjectUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(EditSiteMakerProjectUseCaseProtocol.self) { r in
            DefaultEditSiteMakerProjectUseCase(
                repository: r.resolve(SiteMakerRepositoryProtocol.self)!
            )
        }
        .inObjectScope(.transient)

        container.register(BuilderWorkspaceSceneViewModelFactoryProtocol.self) { r in
            DefaultBuilderWorkspaceSceneViewModelFactory(
                createProjectUseCase: r.resolve(CreateSiteMakerProjectUseCaseProtocol.self)!,
                fetchProjectUseCase: r.resolve(FetchSiteMakerProjectUseCaseProtocol.self)!,
                uploadAssetUseCase: r.resolve(UploadSiteMakerAssetUseCaseProtocol.self)!,
                clarifyProjectUseCase: r.resolve(ClarifySiteMakerProjectUseCaseProtocol.self)!,
                generateProjectUseCase: r.resolve(GenerateSiteMakerProjectUseCaseProtocol.self)!,
                editProjectUseCase: r.resolve(EditSiteMakerProjectUseCaseProtocol.self)!
            )
        }
        .inObjectScope(.container)

        container.register(AppFlowViewModel.self) { r in
            AppFlowViewModel(
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!
            )
        }
        .inObjectScope(.container)

        container.register(TextToVideoSceneViewModel.self) { _ in
            TextToVideoSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self) { _ in
            TextToVideoLoadingSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self, name: "AnimateImage") { _ in
            TextToVideoLoadingSceneViewModel(title: "Animate Photo")
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self, name: "FrameToVideo") { _ in
            TextToVideoLoadingSceneViewModel(title: "Frame to Video")
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self, name: "VoiceGen") { _ in
            TextToVideoLoadingSceneViewModel(
                title: "Voice Gen",
                heading: "Generating voiceover...",
                subtitle: "Please wait, it won't take long"
            )
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self, name: "Transcribe") { _ in
            TextToVideoLoadingSceneViewModel(
                title: "Transcribe",
                heading: "Transcribing File...",
                subtitle: "Extracting text from audio. Please wait."
            )
        }
        .inObjectScope(.transient)

        container.register(TextToVideoLoadingSceneViewModel.self, name: "AIImage") { _ in
            TextToVideoLoadingSceneViewModel(title: "AI Image")
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self) { _ in
            TextToVideoFailedSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self, name: "AnimateImage") { _ in
            TextToVideoFailedSceneViewModel(title: "Animate Photo")
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self, name: "FrameToVideo") { _ in
            TextToVideoFailedSceneViewModel(title: "Frame to Video")
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self, name: "VoiceGen") { _ in
            TextToVideoFailedSceneViewModel(
                title: "Voice Gen",
                subtitle: "We couldn't create your voiceover. Don't worry, your tokens have not been deducted."
            )
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self, name: "Transcribe") { _ in
            TextToVideoFailedSceneViewModel(
                title: "Transcribe",
                heading: "Transcription Failed",
                subtitle: "We couldn't process this file. Don't worry, your tokens have not been deducted."
            )
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFailedSceneViewModel.self, name: "AIImage") { _ in
            TextToVideoFailedSceneViewModel(
                title: "AI Image",
                subtitle: "We couldn't create your image. Don't worry, your tokens have not been deducted."
            )
        }
        .inObjectScope(.transient)

        container.register(TextToVideoResultSceneViewModel.self) { _, videoURL in
            TextToVideoResultSceneViewModel(videoURL: videoURL)
        }
        .inObjectScope(.transient)

        container.register(TextToVideoFlowViewModel.self) { (r: Resolver, initialPrompt: String?) in
            let viewModel = TextToVideoFlowViewModel(
                sceneViewModel: r.resolve(TextToVideoSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self)!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self)!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                generateTextToVideoUseCase: r.resolve(GenerateTextToVideoUseCase.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { videoURL in
                    r.resolve(TextToVideoResultSceneViewModel.self, argument: videoURL) ?? TextToVideoResultSceneViewModel(videoURL: videoURL)
                }
            )
            viewModel.applyLaunchPrompt(initialPrompt)
            return viewModel
        }
        .inObjectScope(.transient)

        container.register(AnimateImageSceneViewModel.self) { _ in
            AnimateImageSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(AnimateImageFlowViewModel.self) { (r: Resolver, initialPrompt: String?) in
            let viewModel = AnimateImageFlowViewModel(
                sceneViewModel: r.resolve(AnimateImageSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self, name: "AnimateImage")!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self, name: "AnimateImage")!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                animateImageUseCase: r.resolve(AnimateImageUseCase.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { videoURL in
                    r.resolve(TextToVideoResultSceneViewModel.self, argument: videoURL) ?? TextToVideoResultSceneViewModel(videoURL: videoURL)
                }
            )
            viewModel.applyLaunchPrompt(initialPrompt)
            return viewModel
        }
        .inObjectScope(.transient)

        container.register(FrameToVideoSceneViewModel.self) { _ in
            FrameToVideoSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(FrameToVideoFlowViewModel.self) { (r: Resolver, initialPrompt: String?) in
            let viewModel = FrameToVideoFlowViewModel(
                sceneViewModel: r.resolve(FrameToVideoSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self, name: "FrameToVideo")!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self, name: "FrameToVideo")!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                frameToVideoUseCase: r.resolve(FrameToVideoUseCase.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { videoURL in
                    r.resolve(TextToVideoResultSceneViewModel.self, argument: videoURL) ?? TextToVideoResultSceneViewModel(videoURL: videoURL)
                }
            )
            viewModel.applyLaunchPrompt(initialPrompt)
            return viewModel
        }
        .inObjectScope(.transient)

        container.register(VoiceGenSceneViewModel.self) { _ in
            VoiceGenSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(VoiceGenResultSceneViewModel.self) { _, audioURL, title in
            VoiceGenResultSceneViewModel(audioURL: audioURL, displayTitle: title)
        }
        .inObjectScope(.transient)

        container.register(VoiceGenFlowViewModel.self) { r in
            VoiceGenFlowViewModel(
                sceneViewModel: r.resolve(VoiceGenSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self, name: "VoiceGen")!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self, name: "VoiceGen")!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                voiceGenUseCase: r.resolve(VoiceGenUseCase.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { audioURL, title in
                    r.resolve(VoiceGenResultSceneViewModel.self, arguments: audioURL, title)
                        ?? VoiceGenResultSceneViewModel(audioURL: audioURL, displayTitle: title)
                }
            )
        }
        .inObjectScope(.transient)

        container.register(TranscribeSceneViewModel.self) { _ in
            TranscribeSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(TranscribeResultSceneViewModel.self) { _, payload in
            TranscribeResultSceneViewModel(payload: payload)
        }
        .inObjectScope(.transient)

        container.register(TranscribeFlowViewModel.self) { r in
            TranscribeFlowViewModel(
                sceneViewModel: r.resolve(TranscribeSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self, name: "Transcribe")!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self, name: "Transcribe")!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                transcribeUseCase: r.resolve(TranscribeUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { payload in
                    r.resolve(TranscribeResultSceneViewModel.self, argument: payload)
                        ?? TranscribeResultSceneViewModel(payload: payload)
                }
            )
        }
        .inObjectScope(.transient)

        container.register(AIImageSceneViewModel.self) { _ in
            AIImageSceneViewModel()
        }
        .inObjectScope(.transient)

        container.register(AIImageResultSceneViewModel.self) { _, imageURL in
            AIImageResultSceneViewModel(imageURL: imageURL)
        }
        .inObjectScope(.transient)

        container.register(AIImageFlowViewModel.self) { (r: Resolver, initialPrompt: String?) in
            let viewModel = AIImageFlowViewModel(
                sceneViewModel: r.resolve(AIImageSceneViewModel.self)!,
                loadingViewModel: r.resolve(TextToVideoLoadingSceneViewModel.self, name: "AIImage")!,
                failedViewModel: r.resolve(TextToVideoFailedSceneViewModel.self, name: "AIImage")!,
                fetchProfileUseCase: r.resolve(FetchProfileUseCase.self)!,
                authorizeUserUseCase: r.resolve(AuthorizeUserUseCase.self)!,
                setFreeGenerationsUseCase: r.resolve(SetFreeGenerationsUseCase.self)!,
                addGenerationsUseCase: r.resolve(AddGenerationsUseCase.self)!,
                fetchServicePricesUseCase: r.resolve(FetchServicePricesUseCase.self)!,
                generateAIImageUseCase: r.resolve(GenerateAIImageUseCase.self)!,
                generationStatusUseCase: r.resolve(GenerationStatusUseCase.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!,
                pendingRecoveryStore: r.resolve(PendingHistoryRecoveryStore.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                aiProcessingConsentManager: r.resolve(AIProcessingConsentManaging.self)!,
                resultViewModelFactory: { imageURL in
                    r.resolve(AIImageResultSceneViewModel.self, argument: imageURL)
                        ?? AIImageResultSceneViewModel(imageURL: imageURL)
                }
            )
            viewModel.applyLaunchPrompt(initialPrompt)
            return viewModel
        }
        .inObjectScope(.transient)

        // MARK: - Root Tab (MVVM)

        container.register(RootHomeSceneViewModel.self) { r in
            RootHomeSceneViewModel(
                purchaseManager: r.resolve(PurchaseManager.self)!,
                historyRepository: r.resolve(HistoryRepository.self)!
            )
        }
        .inObjectScope(.container)

        container.register(RootHistorySceneViewModel.self) { r in
            RootHistorySceneViewModel(
                historyRepository: r.resolve(HistoryRepository.self)!
            )
        }
        .inObjectScope(.container)

        container.register(Base44HomeSceneViewModel.self) { r in
            Base44HomeSceneViewModel(
                fetchProjectsUseCase: r.resolve(FetchSiteMakerProjectsUseCaseProtocol.self)!
            )
        }
        .inObjectScope(.container)

        container.register(RootSettingsSceneViewModel.self) { r in
            RootSettingsSceneViewModel(
                purchaseManager: r.resolve(PurchaseManager.self)!,
                userDefaults: .standard,
                bundle: .main,
                supportMailBuilder: r.resolve(SupportMailComposerBuilding.self)!,
                notificationsScheduler: r.resolve(OnboardingNotificationsScheduling.self)!
            )
        }
        .inObjectScope(.container)

        container.register(RateUsViewModel.self) { r in
            RateUsViewModel(
                supportMailBuilder: r.resolve(SupportMailComposerBuilding.self)!,
                purchaseManager: r.resolve(PurchaseManager.self)!,
                rateUsScheduler: r.resolve(RateUsScheduler.self)!,
                bundle: .main,
                appStoreURL: AppExternalResources.appStoreURL
            )
        }
        .inObjectScope(.transient)

        container.register(RootTabViewModel.self) { r in
            RootTabViewModel(
                homeViewModel: r.resolve(Base44HomeSceneViewModel.self)!,
                settingsViewModel: r.resolve(RootSettingsSceneViewModel.self)!,
                billingAccessResolver: r.resolve(BillingAccessResolving.self)!,
                builderViewModelFactory: r.resolve(BuilderWorkspaceSceneViewModelFactoryProtocol.self)!
            )
        }
        .inObjectScope(.container)
    }
}

@MainActor
final class DefaultHistoryRepository: HistoryRepository {
    var entriesPublisher: AnyPublisher<[HistoryEntry], Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject: CurrentValueSubject<[HistoryEntry], Never>
    private let storageURL: URL
    private let mediaDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let historyDirectoryURL = appSupport.appendingPathComponent("History", isDirectory: true)
        let mediaDirectoryURL = historyDirectoryURL.appendingPathComponent("Media", isDirectory: true)
        let storageURL = historyDirectoryURL.appendingPathComponent("history_entries_v1.json")

        try? fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)

        self.storageURL = storageURL
        self.mediaDirectoryURL = mediaDirectoryURL
        self.encoder.outputFormatting = [.sortedKeys]

        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? decoder.decode([HistoryEntry].self, from: data) {
            self.subject = CurrentValueSubject(decoded.sorted(by: { $0.createdAt > $1.createdAt }))
        } else {
            self.subject = CurrentValueSubject([])
        }
    }

    func entries() -> [HistoryEntry] {
        subject.value
    }

    @discardableResult
    func createProcessingEntry(flowKind: HistoryFlowKind, title: String, prompt: String?) -> UUID {
        let safeTitle = sanitizedTitle(from: title, fallback: defaultTitle(for: flowKind))
        let now = Date()
        let entry = HistoryEntry(
            id: UUID(),
            title: safeTitle,
            prompt: sanitizedPrompt(from: prompt),
            flowKind: flowKind,
            status: .processing,
            createdAt: now,
            updatedAt: now,
            mediaFileName: nil,
            transcribePayload: nil
        )

        var items = subject.value
        items.insert(entry, at: 0)
        publish(items)
        return entry.id
    }

    func markEntryReady(
        id: UUID,
        mediaLocalURL: URL?,
        transcribePayload: HistoryTranscribePayload?
    ) {
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        var item = items[index]
        item.status = .ready
        item.updatedAt = Date()
        item.transcribePayload = transcribePayload

        if let mediaLocalURL {
            item.mediaFileName = persistMediaFile(localURL: mediaLocalURL, flowKind: item.flowKind)
        }

        items[index] = item
        publish(items)
    }

    func markEntryFailed(id: UUID) {
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .failed
        items[index].updatedAt = Date()
        publish(items)
    }

    func renameEntry(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HistoryRepositoryError.invalidTitle
        }

        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = trimmed
        items[index].updatedAt = Date()
        publish(items)
    }

    func deleteEntry(id: UUID) {
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }

        let removed = items.remove(at: index)
        if let mediaFileName = removed.mediaFileName {
            let fileURL = mediaDirectoryURL.appendingPathComponent(mediaFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }

        publish(items)
    }

    func mediaURL(for entry: HistoryEntry) -> URL? {
        guard let mediaFileName = entry.mediaFileName else { return nil }
        let url = mediaDirectoryURL.appendingPathComponent(mediaFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func publish(_ items: [HistoryEntry]) {
        let sorted = items.sorted(by: { $0.createdAt > $1.createdAt })
        subject.send(sorted)
        persist(sorted)
    }

    private func persist(_ items: [HistoryEntry]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func persistMediaFile(localURL: URL, flowKind: HistoryFlowKind) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: localURL.path) else { return nil }

        let sourceExtension = localURL.pathExtension.isEmpty
            ? defaultExtension(for: flowKind)
            : localURL.pathExtension

        let fileName = "\(flowKind.rawValue)_\(UUID().uuidString).\(sourceExtension)"
        let destinationURL = mediaDirectoryURL.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: localURL, to: destinationURL)
            return fileName
        } catch {
            return nil
        }
    }

    private func defaultExtension(for flowKind: HistoryFlowKind) -> String {
        switch flowKind {
        case .textToVideo, .animateImage, .frameToVideo:
            return "mp4"
        case .aiImage:
            return "png"
        case .voiceGen:
            return "mp3"
        case .transcribe:
            return "txt"
        }
    }

    private func defaultTitle(for flowKind: HistoryFlowKind) -> String {
        switch flowKind {
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

    private func sanitizedTitle(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback
        }
        return String(trimmed.prefix(80))
    }

    private func sanitizedPrompt(from value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(2_500))
    }
}

@MainActor
final class InMemoryHistoryRepository: HistoryRepository {
    var entriesPublisher: AnyPublisher<[HistoryEntry], Never> {
        subject.eraseToAnyPublisher()
    }

    private let subject = CurrentValueSubject<[HistoryEntry], Never>([])

    func entries() -> [HistoryEntry] {
        subject.value
    }

    @discardableResult
    func createProcessingEntry(flowKind: HistoryFlowKind, title: String, prompt: String?) -> UUID {
        let id = UUID()
        let entry = HistoryEntry(
            id: id,
            title: title.isEmpty ? "History item" : title,
            prompt: prompt?.trimmingCharacters(in: .whitespacesAndNewlines),
            flowKind: flowKind,
            status: .processing,
            createdAt: Date(),
            updatedAt: Date(),
            mediaFileName: nil,
            transcribePayload: nil
        )
        subject.send([entry] + subject.value)
        return id
    }

    func markEntryReady(id: UUID, mediaLocalURL: URL?, transcribePayload: HistoryTranscribePayload?) {
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .ready
        items[index].updatedAt = Date()
        items[index].transcribePayload = transcribePayload
        subject.send(items)
    }

    func markEntryFailed(id: UUID) {
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .failed
        items[index].updatedAt = Date()
        subject.send(items)
    }

    func renameEntry(id: UUID, newTitle: String) throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HistoryRepositoryError.invalidTitle
        }
        var items = subject.value
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = trimmed
        subject.send(items)
    }

    func deleteEntry(id: UUID) {
        subject.send(subject.value.filter { $0.id != id })
    }

    func mediaURL(for entry: HistoryEntry) -> URL? {
        nil
    }
}

enum PendingHistoryRecoveryKind: String, Codable, Sendable {
    case generation
    case transcribe
}

enum PendingHistoryRecoveryStage: String, Codable, Sendable {
    case starting
    case polling
}

struct PendingTranscribeRecoveryMetadata: Codable, Hashable, Sendable {
    let fileName: String
    let isVideo: Bool
    let outputFormat: HistoryTranscribeOutputFormat
    let timestampsEnabled: Bool
    let sourceMimeType: String?
    let persistedMediaFileName: String?

    func clearingPersistedMediaReference() -> PendingTranscribeRecoveryMetadata {
        PendingTranscribeRecoveryMetadata(
            fileName: fileName,
            isVideo: isVideo,
            outputFormat: outputFormat,
            timestampsEnabled: timestampsEnabled,
            sourceMimeType: sourceMimeType,
            persistedMediaFileName: nil
        )
    }
}

struct PendingHistoryRecoveryRecord: Codable, Hashable, Sendable, Identifiable {
    let historyEntryId: UUID
    let flowKind: HistoryFlowKind
    let recoveryKind: PendingHistoryRecoveryKind
    var stage: PendingHistoryRecoveryStage
    var userId: String?
    var remoteIdentifier: String?
    var transcribeMetadata: PendingTranscribeRecoveryMetadata?
    let createdAt: Date
    var updatedAt: Date

    var id: UUID { historyEntryId }

    init(
        historyEntryId: UUID,
        flowKind: HistoryFlowKind,
        recoveryKind: PendingHistoryRecoveryKind,
        stage: PendingHistoryRecoveryStage,
        userId: String? = nil,
        remoteIdentifier: String? = nil,
        transcribeMetadata: PendingTranscribeRecoveryMetadata? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.historyEntryId = historyEntryId
        self.flowKind = flowKind
        self.recoveryKind = recoveryKind
        self.stage = stage
        self.userId = userId
        self.remoteIdentifier = remoteIdentifier
        self.transcribeMetadata = transcribeMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

protocol PendingHistoryRecoveryStore: Sendable {
    func loadRecords() async -> [PendingHistoryRecoveryRecord]
    func upsert(_ record: PendingHistoryRecoveryRecord) async
    func remove(historyEntryId: UUID) async
}

actor PendingHistoryRecoveryFileStore: PendingHistoryRecoveryStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var records: [PendingHistoryRecoveryRecord]

    init(filename: String = "pending_history_recovery_v1.json") {
        let fileManager = FileManager.default
        let historyDirectoryURL = Self.historyDirectoryURL(fileManager: fileManager)
        try? fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)

        fileURL = historyDirectoryURL.appendingPathComponent(filename)
        encoder.outputFormatting = [.sortedKeys]

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([PendingHistoryRecoveryRecord].self, from: data) {
            records = decoded
        } else {
            records = []
        }
    }

    func loadRecords() async -> [PendingHistoryRecoveryRecord] {
        records
    }

    func upsert(_ record: PendingHistoryRecoveryRecord) async {
        if let index = records.firstIndex(where: { $0.historyEntryId == record.historyEntryId }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
    }

    func remove(historyEntryId: UUID) async {
        records.removeAll { $0.historyEntryId == historyEntryId }
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func historyDirectoryURL(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return appSupport.appendingPathComponent("History", isDirectory: true)
    }
}

@MainActor
final class PendingHistoryRecoveryRunner {
    private let store: PendingHistoryRecoveryStore
    private let historyRepository: HistoryRepository
    private let generationStatusUseCase: GenerationStatusUseCase
    private let transcribeUseCase: TranscribeUseCase
    private let fetchProfileUseCase: FetchProfileUseCase
    private let purchaseManager: PurchaseManager
    private let sessionStartedAt: Date

    private var recoveryTasks: [UUID: Task<Void, Never>] = [:]
    private var isReconciling = false

    init(
        store: PendingHistoryRecoveryStore,
        historyRepository: HistoryRepository,
        generationStatusUseCase: GenerationStatusUseCase,
        transcribeUseCase: TranscribeUseCase,
        fetchProfileUseCase: FetchProfileUseCase,
        purchaseManager: PurchaseManager
    ) {
        self.store = store
        self.historyRepository = historyRepository
        self.generationStatusUseCase = generationStatusUseCase
        self.transcribeUseCase = transcribeUseCase
        self.fetchProfileUseCase = fetchProfileUseCase
        self.purchaseManager = purchaseManager
        self.sessionStartedAt = Date()
    }

    func recoverPendingItemsIfNeeded() async {
        guard !isReconciling else { return }
        isReconciling = true
        defer { isReconciling = false }

        let knownEntries = Dictionary(uniqueKeysWithValues: historyRepository.entries().map { ($0.id, $0) })
        let staleRecords = await store.loadRecords().filter { $0.updatedAt < sessionStartedAt }

        for var record in staleRecords {
            guard let entry = knownEntries[record.historyEntryId] else {
                await store.remove(historyEntryId: record.historyEntryId)
                continue
            }

            guard entry.status == .processing else {
                await store.remove(historyEntryId: record.historyEntryId)
                continue
            }

            switch record.stage {
            case .starting:
                switch record.recoveryKind {
                case .generation:
                    historyRepository.markEntryFailed(id: record.historyEntryId)
                    await refreshBalanceIfPossible(for: record.userId)
                    await store.remove(historyEntryId: record.historyEntryId)
                case .transcribe:
                    guard recoveryTasks[record.historyEntryId] == nil else { continue }

                    record.updatedAt = sessionStartedAt
                    await store.upsert(record)

                    recoveryTasks[record.historyEntryId] = Task { [weak self] in
                        await self?.recover(record)
                    }
                }

            case .polling:
                guard recoveryTasks[record.historyEntryId] == nil else { continue }

                record.updatedAt = sessionStartedAt
                await store.upsert(record)

                recoveryTasks[record.historyEntryId] = Task { [weak self] in
                    await self?.recover(record)
                }
            }
        }
    }

    private func recover(_ record: PendingHistoryRecoveryRecord) async {
        defer {
            recoveryTasks[record.historyEntryId] = nil
        }

        let userId = record.userId?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch record.recoveryKind {
            case .generation:
                guard let userId, !userId.isEmpty,
                      let remoteIdentifier = record.remoteIdentifier,
                      !remoteIdentifier.isEmpty else {
                    throw APIError.backendMessage("Pending generation recovery metadata is incomplete")
                }

                let payload = try await pollRecoveredGenerationResult(
                    userId: userId,
                    jobId: remoteIdentifier,
                    flowKind: record.flowKind
                )
                let temporaryMediaURL = try writeRecoveredMedia(
                    payload.resultData,
                    flowKind: record.flowKind
                )

                historyRepository.markEntryReady(
                    id: record.historyEntryId,
                    mediaLocalURL: temporaryMediaURL,
                    transcribePayload: nil
                )
                try? FileManager.default.removeItem(at: temporaryMediaURL)

            case .transcribe:
                guard let metadata = record.transcribeMetadata else {
                    throw APIError.backendMessage("Pending transcribe recovery metadata is incomplete")
                }

                let taskId: String
                switch record.stage {
                case .starting:
                    guard let userId, !userId.isEmpty else {
                        throw APIError.backendMessage("Pending transcribe recovery metadata is incomplete")
                    }
                    guard let persistedMediaFileName = metadata.persistedMediaFileName,
                          let sourceMimeType = metadata.sourceMimeType else {
                        throw APIError.backendMessage("Pending transcribe recovery metadata is incomplete")
                    }

                    let selectedMedia = try TranscribeRecoveryMediaStore.load(
                        persistedFileName: persistedMediaFileName,
                        originalFileName: metadata.fileName,
                        mimeType: sourceMimeType,
                        isVideo: metadata.isVideo
                    )
                    let binaryUpload = try await TranscribeUploadBuilder.makeBinaryUpload(from: selectedMedia)
                    let request = TranscribeRequest(
                        payloadData: try buildRecoveredTranscribePayloadData(
                            userId: userId,
                            isVideo: metadata.isVideo
                        ),
                        localFile: binaryUpload
                    )
                    let startData = try await transcribeUseCase.start(request)
                    taskId = startData.taskId

                    var pollingRecord = record
                    pollingRecord.stage = .polling
                    pollingRecord.remoteIdentifier = taskId
                    pollingRecord.transcribeMetadata = metadata.clearingPersistedMediaReference()
                    pollingRecord.updatedAt = Date()
                    await store.upsert(pollingRecord)
                    TranscribeRecoveryMediaStore.remove(fileName: persistedMediaFileName)

                case .polling:
                    guard let remoteIdentifier = record.remoteIdentifier,
                          !remoteIdentifier.isEmpty else {
                        throw APIError.backendMessage("Pending transcribe recovery metadata is incomplete")
                    }
                    taskId = remoteIdentifier
                }

                let backendResult = try await transcribeUseCase.resume(taskId: taskId)
                let historyPayload = makeRecoveredTranscribePayload(
                    from: backendResult,
                    metadata: metadata
                )

                historyRepository.markEntryReady(
                    id: record.historyEntryId,
                    mediaLocalURL: nil,
                    transcribePayload: historyPayload
                )
            }

            await refreshBalanceIfPossible(for: userId)
            cleanupRecoveredTranscribeMediaIfNeeded(record.transcribeMetadata)
            await store.remove(historyEntryId: record.historyEntryId)
        } catch is CancellationError {
            return
        } catch {
            historyRepository.markEntryFailed(id: record.historyEntryId)
            await refreshBalanceIfPossible(for: userId)
            cleanupRecoveredTranscribeMediaIfNeeded(record.transcribeMetadata)
            await store.remove(historyEntryId: record.historyEntryId)
        }
    }

    private func refreshBalanceIfPossible(for userId: String?) async {
        guard let userId, !userId.isEmpty else { return }
        guard let profile = try? await fetchProfileUseCase.execute(userId: userId) else { return }
        purchaseManager.updateAvailableGenerations(profile.availableGenerations)
    }

    private func buildRecoveredTranscribePayloadData(userId: String, isVideo: Bool) throws -> Data {
        let payload: [String: Any] = [
            "device_id": userId,
            "is_video": isVideo
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func cleanupRecoveredTranscribeMediaIfNeeded(_ metadata: PendingTranscribeRecoveryMetadata?) {
        TranscribeRecoveryMediaStore.remove(fileName: metadata?.persistedMediaFileName)
    }

    private func pollRecoveredGenerationResult(
        userId: String,
        jobId: String,
        flowKind: HistoryFlowKind
    ) async throws -> BackendGenerationStatusPayload {
        let maxAttempts = 1_050
        let pollingIntervalNanoseconds = generationPollingInterval(for: flowKind)

        for attempt in 0..<maxAttempts {
            do {
                return try await generationStatusUseCase.execute(userId: userId, jobId: jobId)
            } catch {
                guard isPendingGenerationStatusError(error), attempt < maxAttempts - 1 else {
                    throw error
                }

                try await Task.sleep(nanoseconds: pollingIntervalNanoseconds)
            }
        }

        throw APIError.backendMessage("Generation timeout")
    }

    private func generationPollingInterval(for flowKind: HistoryFlowKind) -> UInt64 {
        switch flowKind {
        case .aiImage, .frameToVideo:
            return 2_000_000_000
        case .textToVideo, .animateImage, .voiceGen:
            return 3_000_000_000
        case .transcribe:
            return 10_000_000_000
        }
    }

    private func isPendingGenerationStatusError(_ error: Error) -> Bool {
        if case let APIError.backendMessage(message) = error {
            return isPendingGenerationStatusMessage(message)
        }

        return isPendingGenerationStatusMessage(error.localizedDescription)
    }

    private func isPendingGenerationStatusMessage(_ message: String) -> Bool {
        let text = message.lowercased()
        if text.contains("generation status: error") ||
            text.contains("generation status: failed") ||
            text.contains("generation status: canceled") ||
            text.contains("generation status: cancelled") ||
            text.contains("generation status: expired") {
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

        return rawStatus
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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

    private func writeRecoveredMedia(_ data: Data, flowKind: HistoryFlowKind) throws -> URL {
        let fileManager = FileManager.default
        let folderURL = fileManager.temporaryDirectory.appendingPathComponent(
            "PendingHistoryRecoveryMedia",
            isDirectory: true
        )
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileExtension = mediaFileExtension(for: flowKind, data: data)
        let fileURL = folderURL.appendingPathComponent(
            "\(flowKind.rawValue)_\(UUID().uuidString).\(fileExtension)"
        )
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func mediaFileExtension(for flowKind: HistoryFlowKind, data: Data) -> String {
        switch flowKind {
        case .textToVideo, .animateImage, .frameToVideo:
            return "mp4"
        case .aiImage:
            return detectImageFileExtension(data)
        case .voiceGen:
            return detectAudioFileExtension(data)
        case .transcribe:
            return "txt"
        }
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

    private func makeRecoveredTranscribePayload(
        from backendResult: BackendTranscribeResult,
        metadata: PendingTranscribeRecoveryMetadata
    ) -> HistoryTranscribePayload {
        let decoded = decodeRecoveredTranscribePayload(from: backendResult.rawResultData)
        let summaryTopics = decoded.summaryTopics.isEmpty
            ? fallbackSummaryTopics(from: decoded.transcriptSegments)
            : decoded.summaryTopics

        return HistoryTranscribePayload(
            fileName: metadata.fileName,
            isVideo: metadata.isVideo,
            outputFormat: metadata.outputFormat,
            timestampsEnabled: metadata.timestampsEnabled,
            transcriptSegments: decoded.transcriptSegments.map {
                HistoryTranscriptSegment(text: $0.text, start: $0.start, end: $0.end)
            },
            summaryTopics: summaryTopics,
            rawResultJSONString: backendResult.resultJSONString
        )
    }

    private func decodeRecoveredTranscribePayload(from data: Data) -> DecodedTranscribeRecoveryPayload {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let dictionary = jsonObject as? [String: Any] else {
            return DecodedTranscribeRecoveryPayload(transcriptSegments: [], summaryTopics: [])
        }

        let transcriptionItems = (dictionary["transcription"] as? [[String: Any]]) ?? []
        let transcriptSegments: [RecoveredTranscribeSegment] = transcriptionItems.compactMap { item in
            let text = readString(from: item, keys: ["text"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            let start = readDouble(from: item, keys: ["start"])
            let end = readDouble(from: item, keys: ["end"])

            return RecoveredTranscribeSegment(
                text: text,
                start: start,
                end: max(start, end)
            )
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

        return DecodedTranscribeRecoveryPayload(
            transcriptSegments: transcriptSegments,
            summaryTopics: summaryTopics
        )
    }

    private func fallbackSummaryTopics(from segments: [RecoveredTranscribeSegment]) -> [String] {
        let values = segments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if values.isEmpty {
            return []
        }

        return Array(values.prefix(3))
    }

    private func decodeStringArray(_ value: Any?) -> [String] {
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

    private func readString(from dictionary: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dictionary[key] {
                return String(describing: value)
            }
        }
        return ""
    }

    private func readDouble(from dictionary: [String: Any], keys: [String]) -> Double {
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
}

private extension PendingHistoryRecoveryRunner {
    struct RecoveredTranscribeSegment {
        let text: String
        let start: Double
        let end: Double
    }

    struct DecodedTranscribeRecoveryPayload {
        let transcriptSegments: [RecoveredTranscribeSegment]
        let summaryTopics: [String]
    }
}
