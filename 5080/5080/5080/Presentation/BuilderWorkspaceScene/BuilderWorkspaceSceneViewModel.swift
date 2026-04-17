import Combine
import Foundation

@MainActor
final class BuilderWorkspaceSceneViewModel: ObservableObject {
    @Published var composerText = ""
    @Published private(set) var pendingAttachments: [BuilderAttachmentDraft] = []
    @Published private(set) var uploadedAssets: [BuilderUploadedAssetItem] = []
    @Published private(set) var shareSheetPayload: BuilderShareSheetPayload?
    @Published private(set) var promptText = ""
    @Published private(set) var questions: [BuilderQuestionItem] = []
    @Published private(set) var briefDescription = ""
    @Published private(set) var suggestedTheme = ""
    @Published private(set) var suggestedPalette = ""
    @Published private(set) var projectID: String?
    @Published private(set) var projectSlug: String?
    @Published private(set) var projectStatus = "idle"
    @Published private(set) var previewURL: URL?
    @Published private(set) var previewReloadKey = UUID()
    @Published private(set) var statusLine = "Describe a site and send the prompt to begin."
    @Published private(set) var detailLine = "Clarify questions will appear here."
    @Published private(set) var latestStreamText = "No stream yet."
    @Published private(set) var isBusy = false

    private let launch: BuilderSceneLaunch
    private let createProjectUseCase: CreateSiteMakerProjectUseCaseProtocol
    private let fetchProjectUseCase: FetchSiteMakerProjectUseCaseProtocol
    private let uploadAssetUseCase: UploadSiteMakerAssetUseCaseProtocol
    private let clarifyProjectUseCase: ClarifySiteMakerProjectUseCaseProtocol
    private let generateProjectUseCase: GenerateSiteMakerProjectUseCaseProtocol
    private let editProjectUseCase: EditSiteMakerProjectUseCaseProtocol

    private var didBegin = false

    init(
        launch: BuilderSceneLaunch,
        createProjectUseCase: CreateSiteMakerProjectUseCaseProtocol,
        fetchProjectUseCase: FetchSiteMakerProjectUseCaseProtocol,
        uploadAssetUseCase: UploadSiteMakerAssetUseCaseProtocol,
        clarifyProjectUseCase: ClarifySiteMakerProjectUseCaseProtocol,
        generateProjectUseCase: GenerateSiteMakerProjectUseCaseProtocol,
        editProjectUseCase: EditSiteMakerProjectUseCaseProtocol
    ) {
        self.launch = launch
        self.createProjectUseCase = createProjectUseCase
        self.fetchProjectUseCase = fetchProjectUseCase
        self.uploadAssetUseCase = uploadAssetUseCase
        self.clarifyProjectUseCase = clarifyProjectUseCase
        self.generateProjectUseCase = generateProjectUseCase
        self.editProjectUseCase = editProjectUseCase
    }

    var hasPrompt: Bool {
        !promptText.isEmpty
    }

    var hasQuestions: Bool {
        !questions.isEmpty
    }

    var hasPreview: Bool {
        previewURL != nil
    }

    var canGenerate: Bool {
        !isBusy && hasQuestions && !briefDescription.isEmpty
    }

    var composerPlaceholder: String {
        hasPreview
            ? "Describe the edits you want to apply..."
            : "Describe what you want to create..."
    }

    func beginIfNeeded() async {
        guard !didBegin else { return }
        didBegin = true

        switch launch {
        case .new(let prompt, let attachments):
            pendingAttachments = attachments
            await clarify(prompt: prompt)

        case .existing(let project):
            await loadProject(projectID: project.id)
        }
    }

    func addAttachments(_ attachments: [BuilderAttachmentDraft]) {
        pendingAttachments.append(contentsOf: attachments)
    }

    func removePendingAttachment(id: BuilderAttachmentDraft.ID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func updateSelection(questionID: String, selectedIndex: Int) {
        guard let index = questions.firstIndex(where: { $0.id == questionID }) else {
            return
        }

        questions[index].selectedIndex = selectedIndex
    }

    func submitComposer() async {
        let text = composerText.trimmed

        guard !text.isEmpty else {
            handle(SiteMakerBuilderError.emptyPrompt, fallback: "Prompt is empty.")
            return
        }

        composerText = ""

        if hasPreview {
            await applyEdit(instruction: text)
        } else {
            await clarify(prompt: text)
        }
    }

    func generateSite() async {
        do {
            guard let projectID else {
                throw SiteMakerBuilderError.missingProject
            }

            guard hasQuestions, !briefDescription.isEmpty else {
                throw SiteMakerBuilderError.missingClarifyResult
            }

            isBusy = true
            statusLine = "Generating site..."
            detailLine = "Spec, code, files, and build events will stream from the backend."
            latestStreamText = "Waiting for spec stream..."

            let prompt = try await prepareGeneratePrompt()

            try await generateProjectUseCase.execute(
                projectID: projectID,
                prompt: prompt
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Site is live."
                )
            }
        } catch {
            handle(error, fallback: "Generate failed.")
        }

        isBusy = false
    }

    func sharePreviewLink() {
        do {
            guard let previewURL else {
                throw SiteMakerBuilderError.missingPreviewURL
            }

            shareSheetPayload = BuilderShareSheetPayload(items: [previewURL])
        } catch {
            handle(error, fallback: "Preview share failed.")
        }
    }

    func dismissShareSheet() {
        shareSheetPayload = nil
    }

    func presentAttachmentError(_ message: String) {
        detailLine = message
        latestStreamText = message
    }
}

private extension BuilderWorkspaceSceneViewModel {
    func loadProject(projectID: String) async {
        do {
            let project = try await fetchProjectUseCase.execute(id: projectID)
            applyLoadedProject(project)
        } catch {
            handle(error, fallback: "Couldn't open the project.")
        }
    }

    func applyLoadedProject(_ project: SiteMakerProject) {
        projectID = project.id
        projectSlug = project.slug
        projectStatus = project.status
        promptText = project.description?.trimmed ?? project.name
        briefDescription = project.description?.trimmed ?? ""
        questions = []

        if let previewURLString = project.previewURLString,
           let url = URL(string: previewURLString) {
            previewURL = url
        } else {
            previewURL = nil
        }

        if previewURL != nil {
            statusLine = "Project loaded."
            detailLine = project.previewURLString ?? "Preview is ready."
        } else {
            statusLine = "Draft loaded."
            detailLine = "Continue in chat and generate when you're ready."
        }

        latestStreamText = project.name
    }

    func clarify(prompt: String) async {
        do {
            isBusy = true
            statusLine = "Preparing project..."
            detailLine = "Creating a draft project before clarify."
            latestStreamText = "Waiting for clarify stream..."
            previewURL = nil
            projectStatus = "draft"

            let preparedPrompt = try await preparePromptWithPendingAttachments(
                prompt,
                isEditInstruction: false
            )
            let projectID = try await ensureProject(prompt: prompt)

            promptText = prompt
            questions = []
            briefDescription = ""
            suggestedTheme = ""
            suggestedPalette = ""

            try await clarifyProjectUseCase.execute(
                projectID: projectID,
                prompt: preparedPrompt
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Site is live."
                )
            }
        } catch {
            handle(error, fallback: "Clarify failed.")
        }

        isBusy = false
    }

    func applyEdit(instruction: String) async {
        do {
            guard let projectID else {
                throw SiteMakerBuilderError.missingProject
            }

            isBusy = true
            statusLine = "Applying edit..."
            detailLine = "Editing the generated site and rebuilding preview."
            latestStreamText = instruction

            let preparedInstruction = try await preparePromptWithPendingAttachments(
                instruction,
                isEditInstruction: true
            )

            try await editProjectUseCase.execute(
                projectID: projectID,
                instruction: preparedInstruction
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Preview updated."
                )
            }
        } catch {
            handle(error, fallback: "Edit failed.")
        }

        isBusy = false
    }

    func ensureProject(prompt: String) async throws -> String {
        if let projectID {
            return projectID
        }

        let project = try await createProjectUseCase.execute(prompt: prompt)
        self.projectID = project.id
        projectSlug = project.slug
        projectStatus = project.status
        statusLine = "Project created."
        detailLine = "Project \(project.slug) is ready for clarify."

        return project.id
    }

    func prepareGeneratePrompt() async throws -> String {
        let preferenceLines = questions.map { question in
            let option = question.options[safe: question.selectedIndex] ?? question.options.first ?? "-"
            return "\(question.title) -> \(option)"
        }

        let preferencesText = preferenceLines.joined(separator: "\n")
        let uploadedAssetLines = uploadedAssets
            .map { "- \($0.fileName): \($0.url.absoluteString)" }
            .joined(separator: "\n")

        let uploadedAssetsSection = uploadedAssetLines.isEmpty
            ? ""
            : """

            Uploaded assets:
            \(uploadedAssetLines)
            """

        let basePrompt = """
        Original request: \(promptText)

        Design brief: \(briefDescription)

        Suggested theme: \(suggestedTheme)
        Suggested palette: \(suggestedPalette)

        Design preferences:
        \(preferencesText)\(uploadedAssetsSection)
        """

        return try await preparePromptWithPendingAttachments(
            basePrompt,
            isEditInstruction: false
        )
    }

    func preparePromptWithPendingAttachments(
        _ text: String,
        isEditInstruction: Bool
    ) async throws -> String {
        guard !pendingAttachments.isEmpty else {
            return text
        }

        let projectID = try await ensureProject(prompt: text)

        guard let projectSlug else {
            throw SiteMakerBuilderError.missingProject
        }

        statusLine = "Uploading attachments..."
        detailLine = "Sending \(pendingAttachments.count) file(s) to the builder backend."

        var uploadedThisRound: [BuilderUploadedAssetItem] = []

        for attachment in pendingAttachments {
            guard attachment.data.count <= BuilderAttachmentDraft.maxUploadBytes else {
                throw SiteMakerBuilderError.attachmentTooLarge(attachment.displayName)
            }

            let payload = SiteMakerAttachmentUploadPayload(
                fileName: attachment.displayName,
                mimeType: attachment.mimeType,
                data: attachment.data
            )

            let asset = try await uploadAssetUseCase.execute(
                projectID: projectID,
                projectSlug: projectSlug,
                payload: payload
            )

            guard
                let publicURLString = asset.publicURLString,
                let publicURL = URL(string: publicURLString)
            else {
                throw SiteMakerBuilderError.invalidUploadedAssetURL(asset.fileName)
            }

            uploadedThisRound.append(
                BuilderUploadedAssetItem(
                    id: asset.id,
                    fileName: asset.fileName,
                    url: publicURL,
                    mimeType: asset.mimeType
                )
            )

            latestStreamText = asset.fileName
        }

        pendingAttachments = []
        uploadedAssets.append(contentsOf: uploadedThisRound)

        return buildAssetAwareText(
            baseText: text,
            assets: uploadedThisRound,
            isEditInstruction: isEditInstruction
        )
    }

    func buildAssetAwareText(
        baseText: String,
        assets: [BuilderUploadedAssetItem],
        isEditInstruction: Bool
    ) -> String {
        guard !assets.isEmpty else {
            return baseText
        }

        let assetLines = assets
            .map { "- \($0.fileName): \($0.url.absoluteString)" }
            .joined(separator: "\n")

        let usageHint = isEditInstruction
            ? "Use these uploaded assets in the requested edits where they make sense."
            : "Use these uploaded assets where they help the generated site."

        return """
        \(baseText)

        Uploaded project assets:
        \(assetLines)

        \(usageHint)
        Reference the exact URLs above when you need them.
        """
    }

    func handleStreamEvent(
        _ event: SiteMakerStreamEvent,
        buildSuccessLine: String
    ) {
        switch event {
        case .stageStarted(let stage, let message):
            statusLine = message
            detailLine = detailMessage(for: stage)

        case .token(_, let message):
            latestStreamText = message

        case .stageCompleted(_, let message):
            latestStreamText = message

        case .clarifyCompleted(let result):
            briefDescription = result.description
            suggestedTheme = result.suggestedTheme
            suggestedPalette = result.suggestedPalette
            questions = result.questions.map { question in
                BuilderQuestionItem(
                    id: question.id,
                    title: question.title,
                    options: question.options,
                    selectedIndex: question.defaultIndex.clamped(
                        to: 0...(max(0, question.options.count - 1))
                    )
                )
            }
            statusLine = "Clarify complete."
            detailLine = "Pick options and tap Generate."
            latestStreamText = result.description

        case .filesWritten(let count, let durationMs):
            statusLine = "Files written."
            detailLine = "Backend wrote \(count) files."
            latestStreamText = durationMs.map { "duration_ms: \($0)" } ?? "Files ready."

        case .buildCompleted(let outcome):
            guard let url = URL(string: outcome.previewURLString) else {
                handle(
                    SiteMakerBuilderError.invalidPreviewURL(outcome.previewURLString),
                    fallback: "Preview update failed."
                )
                return
            }

            previewURL = url
            previewReloadKey = UUID()
            projectStatus = outcome.isSuccess ? "live" : "error"
            statusLine = buildSuccessLine
            detailLine = outcome.previewURLString
            latestStreamText = outcome.outputPath

        case .message(_, let value):
            latestStreamText = value
        }
    }

    func detailMessage(for stage: SiteMakerStreamStage) -> String {
        switch stage {
        case .clarify:
            return "The backend is writing a richer brief and question set."
        case .spec:
            return "The backend is designing the site structure."
        case .code:
            return "The backend is generating the site code."
        case .build:
            return "The preview is being built and deployed."
        }
    }

    func handle(_ error: Error, fallback: String) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        statusLine = fallback
        detailLine = message
        latestStreamText = message
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
