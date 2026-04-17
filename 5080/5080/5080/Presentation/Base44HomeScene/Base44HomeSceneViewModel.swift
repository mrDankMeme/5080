import Combine
import Foundation

@MainActor
final class Base44HomeSceneViewModel: ObservableObject {
    @Published var draftPrompt = ""
    @Published private(set) var attachments: [BuilderAttachmentDraft] = []
    @Published private(set) var projects: [SiteMakerProjectSummary] = []
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var projectsErrorText: String?

    private let fetchProjectsUseCase: FetchSiteMakerProjectsUseCaseProtocol
    private var didLoadProjects = false

    init(fetchProjectsUseCase: FetchSiteMakerProjectsUseCaseProtocol) {
        self.fetchProjectsUseCase = fetchProjectsUseCase
    }

    var canCreate: Bool {
        !draftPrompt.trimmed.isEmpty
    }

    func loadProjectsIfNeeded() async {
        guard !didLoadProjects else { return }
        didLoadProjects = true
        await refreshProjects()
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
}
