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
    @Published private(set) var busyProjectIDs: Set<String> = []

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
            syncPendingProjectStates()
        } catch {
            projectsErrorText = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            busyProjectIDs = BuilderPendingOperationStore.activeProjectIDs()
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

    func isProjectBusy(_ projectID: String) -> Bool {
        if busyProjectIDs.contains(projectID) {
            return true
        }

        return projects.first(where: { $0.id == projectID })?.isServerGenerationInProgress == true
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
                self?.availableCredits = max(0, value)
            }
            .store(in: &cancellables)
    }

    func refreshCreditsIfNeeded(force: Bool = false) async {
        guard force || !didLoadCredits else { return }
        didLoadCredits = true

        do {
            let currentUser = try await fetchCurrentUserUseCase.execute()
            let backendCredits = max(0, currentUser.credits)
            let localCredits = max(0, purchaseManager.availableGenerations)
            let mergedCredits = max(backendCredits, localCredits)
            availableCredits = mergedCredits
            purchaseManager.updateAvailableGenerations(mergedCredits)
            #if DEBUG
            print(
                "[5080API][Home] Header credits updated to \(availableCredits). backend=\(backendCredits), local=\(localCredits)"
            )
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

    func syncPendingProjectStates() {
        let terminalProjectIDs = projects
            .filter(\.isServerTerminalStatus)
            .map(\.id)

        for projectID in terminalProjectIDs {
            BuilderPendingOperationStore.remove(projectID: projectID)
        }

        let pendingProjectIDs = BuilderPendingOperationStore.activeProjectIDs()
        let backendInProgressProjectIDs = Set(
            projects
                .filter(\.isServerGenerationInProgress)
                .map(\.id)
        )

        busyProjectIDs = pendingProjectIDs.union(backendInProgressProjectIDs)
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

private extension SiteMakerProjectSummary {
    var isServerGenerationInProgress: Bool {
        switch status.trimmed.lowercased() {
        case "building",
             "generating",
             "processing",
             "running",
             "queued",
             "pending",
             "in_progress",
             "in progress",
             "spec",
             "code",
             "build",
             "deploying":
            return true
        default:
            return false
        }
    }

    var isServerTerminalStatus: Bool {
        switch status.trimmed.lowercased() {
        case "live",
             "success",
             "succeeded",
             "completed",
             "complete",
             "error",
             "failed",
             "failure",
             "canceled",
             "cancelled",
             "expired":
            return true
        default:
            return false
        }
    }
}

enum BuilderPendingOperationKind: String, Codable, Sendable {
    case clarify
    case generate
    case edit
}

struct BuilderPendingOperationRecord: Codable, Hashable, Sendable {
    let projectID: String
    let kind: BuilderPendingOperationKind
    let payload: String
    let updatedAt: Date
}

enum BuilderPendingOperationStore {
    private static let storageKey = "BuilderPendingOperationStore.records.v1"
    private static let maxAge: TimeInterval = 60 * 60 * 24

    static func upsert(
        projectID: String,
        kind: BuilderPendingOperationKind,
        payload: String
    ) {
        var records = loadRecords()
        records[projectID] = BuilderPendingOperationRecord(
            projectID: projectID,
            kind: kind,
            payload: payload,
            updatedAt: Date()
        )
        persist(records)
    }

    static func remove(projectID: String) {
        var records = loadRecords()
        records.removeValue(forKey: projectID)
        persist(records)
    }

    static func record(projectID: String) -> BuilderPendingOperationRecord? {
        let records = loadRecords()
        return records[projectID]
    }

    static func activeProjectIDs() -> Set<String> {
        let records = loadRecords()
        return Set(records.keys)
    }
}

private extension BuilderPendingOperationStore {
    static func loadRecords() -> [String: BuilderPendingOperationRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: BuilderPendingOperationRecord].self, from: data)
        else {
            return [:]
        }

        let now = Date()
        return decoded.filter { _, record in
            now.timeIntervalSince(record.updatedAt) <= maxAge
        }
    }

    static func persist(_ records: [String: BuilderPendingOperationRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
