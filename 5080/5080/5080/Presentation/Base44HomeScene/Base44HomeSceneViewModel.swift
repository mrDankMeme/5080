import Combine
import Foundation

@MainActor
final class Base44HomeSceneViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var attachments: [BuilderAttachmentDraft] = []
    @Published private(set) var projects: [SiteMakerProjectSummary] = []
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var projectsErrorText: String?
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var availableCredits: Int

    private let fetchProjectsUseCase: FetchSiteMakerProjectsUseCaseProtocol
    private let fetchCurrentUserUseCase: FetchSiteMakerCurrentUserUseCaseProtocol
    private let purchaseManager: PurchaseManager
    private var didLoadProjects = false
    private var didLoadCredits = false
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchProjectsUseCase: FetchSiteMakerProjectsUseCaseProtocol,
        fetchCurrentUserUseCase: FetchSiteMakerCurrentUserUseCaseProtocol,
        purchaseManager: PurchaseManager
    ) {
        self.fetchProjectsUseCase = fetchProjectsUseCase
        self.fetchCurrentUserUseCase = fetchCurrentUserUseCase
        self.purchaseManager = purchaseManager
        self.isSubscribed = purchaseManager.isSubscribed
        self.availableCredits = max(0, purchaseManager.availableGenerations)
        bindPurchaseManager()
    }

    var canCreate: Bool {
        !draftPrompt.trimmed.isEmpty
    }

    var headerBadgeTitle: String {
        isSubscribed ? formattedCredits : "PRO"
    }

    func loadProjectsIfNeeded() async {
        guard !didLoadProjects else { return }
        didLoadProjects = true
        await refreshContent()
    }

    func refreshContent() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.refreshProjects()
            }
            group.addTask { [weak self] in
                await self?.refreshCreditsIfNeeded(force: true)
            }
        }
    }

    func refreshProjects() async {
        isLoadingProjects = true
        projectsErrorText = nil

        defer {
            isLoadingProjects = false
        }

        do {
            projects = try await fetchProjectsUseCase.execute()
        } catch {
            projectsErrorText = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func appendAttachments(_ newAttachments: [BuilderAttachmentDraft]) {
        attachments.append(contentsOf: newAttachments)
    }

    func removeAttachment(id: BuilderAttachmentDraft.ID) {
        attachments.removeAll { $0.id == id }
    }

    func makeCreateLaunch() -> BuilderSceneLaunch? {
        let prompt = draftPrompt.trimmed
        guard !prompt.isEmpty else {
            return nil
        }

        let launch = BuilderSceneLaunch.new(
            prompt: prompt,
            attachments: attachments
        )

        draftPrompt = ""
        attachments = []

        return launch
    }

    private var formattedCredits: String {
        Self.creditsFormatter.string(from: NSNumber(value: availableCredits)) ?? "\(availableCredits)"
    }

    private func bindPurchaseManager() {
        purchaseManager.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isSubscribed = value
            }
            .store(in: &cancellables)

        purchaseManager.$availableGenerations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self, !self.didLoadCredits else { return }
                self.availableCredits = max(0, value)
            }
            .store(in: &cancellables)
    }

    func refreshCreditsIfNeeded(force: Bool = false) async {
        guard force || !didLoadCredits else { return }
        didLoadCredits = true

        do {
            let currentUser = try await fetchCurrentUserUseCase.execute()
            let resolvedCredits = max(0, currentUser.credits)
            availableCredits = resolvedCredits
            purchaseManager.updateAvailableGenerations(resolvedCredits)
            #if DEBUG
            print("[5080API][Home] Header credits updated to \(availableCredits)")
            #endif
        } catch {
            if availableCredits <= 0 {
                availableCredits = max(0, purchaseManager.availableGenerations)
            }
            #if DEBUG
            print(
                "[5080API][Home] Failed to refresh credits: \(error.localizedDescription). Fallback credits=\(availableCredits)"
            )
            #endif
        }
    }
}

private extension Base44HomeSceneViewModel {
    static let creditsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
