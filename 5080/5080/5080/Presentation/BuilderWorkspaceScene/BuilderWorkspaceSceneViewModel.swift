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
    @Published private(set) var isUploadingAttachments = false
    @Published private(set) var isBackNavigationLocked = false
    @Published private(set) var activeOperationKind: BuilderPendingOperationKind?

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

        if case .new = launch {
            // Keep users on clarify flow until they can start generation explicitly.
            isBackNavigationLocked = true
        }
    }

    var hasPrompt: Bool {
        !promptText.isEmpty
    }

    var hasQuestions: Bool {
        !questions.isEmpty
    }

    var shouldShowClarifyQuestions: Bool {
        hasQuestions && !isGenerationLikeOperationRunning
    }

    var hasPreview: Bool {
        previewURL != nil
    }

    var canGenerate: Bool {
        !isBusy && hasQuestions && !briefDescription.isEmpty
    }

    var canDismiss: Bool {
        !isBackNavigationLocked
    }

    var isGenerationLikeOperationRunning: Bool {
        guard isBusy else { return false }
        return activeOperationKind == .generate || activeOperationKind == .edit
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
        let remainingSlots = max(0, BuilderAttachmentDraft.maxAttachmentCount - pendingAttachments.count)
        guard remainingSlots > 0 else {
            presentAttachmentError("You can attach up to \(BuilderAttachmentDraft.maxAttachmentCount) files.")
            return
        }

        let accepted = Array(attachments.prefix(remainingSlots))
        pendingAttachments.append(contentsOf: accepted)

        if accepted.count < attachments.count {
            presentAttachmentError("Only the first \(BuilderAttachmentDraft.maxAttachmentCount) files were kept.")
        }
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
        guard let projectID else {
            handle(SiteMakerBuilderError.missingProject, fallback: "Generate failed.")
            return
        }

        guard hasQuestions, !briefDescription.isEmpty else {
            handle(SiteMakerBuilderError.missingClarifyResult, fallback: "Generate failed.")
            return
        }

        do {
            let prompt = try await prepareGeneratePrompt()
            // Persist intent before awaiting stream start to survive quick scene transitions.
            BuilderPendingOperationStore.upsert(
                projectID: projectID,
                kind: .generate,
                payload: prompt
            )
            await runGenerateStream(
                projectID: projectID,
                prompt: prompt,
                isResuming: false
            )
        } catch {
            handle(error, fallback: "Generate failed.")
        }
    }

    func sharePreviewLink() {
        do {
            guard let previewURL else {
                throw SiteMakerBuilderError.missingPreviewURL
            }

            shareSheetPayload = BuilderShareSheetPayload(items: [previewURL])
        } catch {
            handle(error, fallback: "Live site share failed.")
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
            if await resumePendingOperationIfNeeded(for: project) {
                return
            }
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

        let normalizedStatus = project.status.trimmed.lowercased()

        if previewURL != nil {
            statusLine = "Project loaded."
            detailLine = project.previewURLString ?? "Live site is ready."
            isBackNavigationLocked = false
        } else if isTerminalErrorStatus(normalizedStatus) {
            statusLine = "Generation failed."
            detailLine = "Backend reported status \"\(project.status)\". You can retry from chat."
            isBackNavigationLocked = false
        } else if isInProgressStatus(normalizedStatus) {
            statusLine = "Generation in progress."
            detailLine = "This project is still building on the server."
            isBackNavigationLocked = false
        } else {
            statusLine = "Draft loaded."
            detailLine = "Continue in chat and generate when you're ready."
            isBackNavigationLocked = false
        }

        latestStreamText = project.name
        activeOperationKind = nil
    }

    func resumePendingOperationIfNeeded(for project: SiteMakerProject) async -> Bool {
        guard let pendingRecord = BuilderPendingOperationStore.record(projectID: project.id) else {
            return false
        }

        let normalizedStatus = project.status.trimmed.lowercased()
        if previewURL != nil || isTerminalErrorStatus(normalizedStatus) {
            BuilderPendingOperationStore.remove(projectID: project.id)
            return false
        }

        switch pendingRecord.kind {
        case .clarify:
            let displayPrompt = project.description?.trimmed ?? project.name
            await runClarifyStream(
                projectID: project.id,
                preparedPrompt: pendingRecord.payload,
                displayPrompt: displayPrompt,
                isResuming: true
            )
        case .generate, .edit:
            await monitorPendingBuild(
                projectID: project.id,
                operation: pendingRecord.kind,
                isResuming: true,
                initialProject: project
            )
        }

        return true
    }

    func clarify(prompt: String) async {
        do {
            let preparedPrompt = try await preparePromptWithPendingAttachments(
                prompt,
                isEditInstruction: false
            )
            let projectID = try await ensureProject(prompt: prompt)
            // Persist intent before awaiting stream start to survive quick scene transitions.
            BuilderPendingOperationStore.upsert(
                projectID: projectID,
                kind: .clarify,
                payload: preparedPrompt
            )

            await runClarifyStream(
                projectID: projectID,
                preparedPrompt: preparedPrompt,
                displayPrompt: prompt,
                isResuming: false
            )
        } catch {
            handle(error, fallback: "Clarify failed.")
        }
    }

    func applyEdit(instruction: String) async {
        guard let projectID else {
            handle(SiteMakerBuilderError.missingProject, fallback: "Edit failed.")
            return
        }

        do {
            let preparedInstruction = try await preparePromptWithPendingAttachments(
                instruction,
                isEditInstruction: true
            )
            // Persist intent before awaiting stream start to survive quick scene transitions.
            BuilderPendingOperationStore.upsert(
                projectID: projectID,
                kind: .edit,
                payload: preparedInstruction
            )
            await runEditStream(
                projectID: projectID,
                instruction: preparedInstruction,
                isResuming: false
            )
        } catch {
            handle(error, fallback: "Edit failed.")
        }
    }

    func runClarifyStream(
        projectID: String,
        preparedPrompt: String,
        displayPrompt: String,
        isResuming: Bool
    ) async {
        isBusy = true
        isBackNavigationLocked = true
        activeOperationKind = .clarify
        defer {
            isBusy = false
            if activeOperationKind == .clarify {
                activeOperationKind = nil
            }
        }
        statusLine = isResuming ? "Resuming draft..." : "Preparing project..."
        detailLine = isResuming
            ? "Restoring clarify questions for this project."
            : "Creating a draft project before clarify."
        latestStreamText = isResuming
            ? "Reconnecting to clarify stream..."
            : "Waiting for clarify stream..."
        previewURL = nil
        projectStatus = "draft"
        promptText = displayPrompt.trimmed
        questions = []
        briefDescription = ""
        suggestedTheme = ""
        suggestedPalette = ""

        BuilderPendingOperationStore.upsert(
            projectID: projectID,
            kind: .clarify,
            payload: preparedPrompt
        )

        do {
            try await clarifyProjectUseCase.execute(
                projectID: projectID,
                prompt: preparedPrompt
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Site is live."
                )
            }
        } catch is CancellationError {
            // Keep pending record for automatic resume after reopening the project.
        } catch {
            BuilderPendingOperationStore.remove(projectID: projectID)
            handle(error, fallback: "Clarify failed.")
        }
    }

    func runGenerateStream(
        projectID: String,
        prompt: String,
        isResuming: Bool
    ) async {
        isBusy = true
        isBackNavigationLocked = false
        activeOperationKind = .generate
        defer {
            isBusy = false
            isBackNavigationLocked = false
            if activeOperationKind == .generate {
                activeOperationKind = nil
            }
        }
        projectStatus = "building"
        statusLine = isResuming ? "Resuming generation..." : "Generating site..."
        detailLine = "Spec, code, files, and build events will stream from the backend. You can leave this screen and resume from Home anytime."
        latestStreamText = isResuming
            ? "Reconnecting to build stream..."
            : "Waiting for spec stream..."

        BuilderPendingOperationStore.upsert(
            projectID: projectID,
            kind: .generate,
            payload: prompt
        )

        do {
            try await generateProjectUseCase.execute(
                projectID: projectID,
                prompt: prompt
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Site is live."
                )
            }
        } catch is CancellationError {
            // Keep pending record for automatic resume after reopening the project.
        } catch {
            if shouldKeepPendingRecord(for: error, operation: .generate) {
                await monitorPendingBuild(
                    projectID: projectID,
                    operation: .generate,
                    isResuming: true,
                    initialProject: nil
                )
            } else {
                BuilderPendingOperationStore.remove(projectID: projectID)
                handle(error, fallback: "Generate failed.")
            }
        }
    }

    func runEditStream(
        projectID: String,
        instruction: String,
        isResuming: Bool
    ) async {
        isBusy = true
        isBackNavigationLocked = false
        activeOperationKind = .edit
        defer {
            isBusy = false
            isBackNavigationLocked = false
            if activeOperationKind == .edit {
                activeOperationKind = nil
            }
        }
        projectStatus = "building"
        statusLine = isResuming ? "Resuming edit..." : "Applying edit..."
        detailLine = "Editing the generated site and rebuilding the live result. You can leave this screen and resume from Home anytime."
        latestStreamText = isResuming
            ? "Reconnecting to build stream..."
            : instruction

        BuilderPendingOperationStore.upsert(
            projectID: projectID,
            kind: .edit,
            payload: instruction
        )

        do {
            try await editProjectUseCase.execute(
                projectID: projectID,
                instruction: instruction
            ) { [weak self] event in
                self?.handleStreamEvent(
                    event,
                    buildSuccessLine: "Live site updated."
                )
            }
        } catch is CancellationError {
            // Keep pending record for automatic resume after reopening the project.
        } catch {
            if shouldKeepPendingRecord(for: error, operation: .edit) {
                await monitorPendingBuild(
                    projectID: projectID,
                    operation: .edit,
                    isResuming: true,
                    initialProject: nil
                )
            } else {
                BuilderPendingOperationStore.remove(projectID: projectID)
                handle(error, fallback: "Edit failed.")
            }
        }
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

        isUploadingAttachments = true
        defer {
            isUploadingAttachments = false
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

    func monitorPendingBuild(
        projectID: String,
        operation: BuilderPendingOperationKind,
        isResuming: Bool,
        initialProject: SiteMakerProject?
    ) async {
        isBusy = true
        isBackNavigationLocked = false
        activeOperationKind = operation
        defer {
            isBusy = false
            isBackNavigationLocked = false
            if activeOperationKind == operation {
                activeOperationKind = nil
            }
        }

        statusLine = operation == .edit
            ? (isResuming ? "Resuming update..." : "Update in progress...")
            : (isResuming ? "Resuming generation..." : "Generation in progress...")
        detailLine = "This project is already running on the server. We'll keep tracking it here."
        latestStreamText = "Syncing project status..."
        projectStatus = initialProject?.status ?? "building"

        if let initialProject,
           applyTerminalBuildStateIfNeeded(from: initialProject, operation: operation) {
            return
        }

        let pollingIntervalNanoseconds: UInt64 = 4_000_000_000
        let maxAttempts = 90

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                do {
                    try await Task.sleep(nanoseconds: pollingIntervalNanoseconds)
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else {
                return
            }

            do {
                let refreshedProject = try await fetchProjectUseCase.execute(id: projectID)
                projectStatus = refreshedProject.status

                if applyTerminalBuildStateIfNeeded(from: refreshedProject, operation: operation) {
                    return
                }

                let currentStatus = refreshedProject.status.trimmed
                latestStreamText = currentStatus.isEmpty
                    ? "Still building on the server..."
                    : "status: \(currentStatus)"
                detailLine = "This project is still building on the server."
            } catch is CancellationError {
                return
            } catch {
                latestStreamText = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }

        statusLine = operation == .edit
            ? "Update continues in background."
            : "Generation continues in background."
        detailLine = "Still running on the server. Reopen this project in a moment to continue."
    }

    @discardableResult
    func applyTerminalBuildStateIfNeeded(
        from project: SiteMakerProject,
        operation: BuilderPendingOperationKind
    ) -> Bool {
        if let previewURLString = project.previewURLString,
           let url = URL(string: previewURLString) {
            previewURL = url
            previewReloadKey = UUID()
            projectStatus = project.status
            statusLine = operation == .edit ? "Live site updated." : "Site is live."
            detailLine = previewURLString
            latestStreamText = project.name
            isBackNavigationLocked = false
            BuilderPendingOperationStore.remove(projectID: project.id)
            return true
        }

        let normalizedStatus = project.status.trimmed.lowercased()
        if isTerminalErrorStatus(normalizedStatus) {
            projectStatus = project.status
            statusLine = operation == .edit ? "Update failed." : "Generate failed."
            detailLine = "Backend reported status \"\(project.status)\"."
            latestStreamText = project.name
            isBackNavigationLocked = false
            BuilderPendingOperationStore.remove(projectID: project.id)
            return true
        }

        return false
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
            guard activeOperationKind == .clarify else {
                // Some generate/edit streams emit clarify payloads as intermediate telemetry.
                // Do not switch the UI back to the question step while a build is already running.
                latestStreamText = result.description
                return
            }

            if let projectID {
                BuilderPendingOperationStore.remove(projectID: projectID)
            }
            briefDescription = result.description
            suggestedTheme = result.suggestedTheme
            suggestedPalette = result.suggestedPalette
            let mappedQuestions = result.questions.map { question in
                BuilderQuestionItem(
                    id: question.id,
                    title: question.title,
                    options: question.options,
                    selectedIndex: question.defaultIndex.clamped(
                        to: 0...(max(0, question.options.count - 1))
                    )
                )
            }
            questions = mappedQuestions
            statusLine = "Clarify complete."
            detailLine = mappedQuestions.isEmpty
                ? "Questions are taking longer than expected. Try reopening the project."
                : "Pick options and tap Generate."
            latestStreamText = result.description
            isBackNavigationLocked = !mappedQuestions.isEmpty

        case .filesWritten(let count, let durationMs):
            statusLine = "Files written."
            detailLine = "Backend wrote \(count) files."
            latestStreamText = durationMs.map { "duration_ms: \($0)" } ?? "Files ready."

        case .buildCompleted(let outcome):
            if let projectID {
                BuilderPendingOperationStore.remove(projectID: projectID)
            }
            guard let url = URL(string: outcome.previewURLString) else {
                handle(
                    SiteMakerBuilderError.invalidPreviewURL(outcome.previewURLString),
                    fallback: "Live site update failed."
                )
                return
            }

            previewURL = url
            previewReloadKey = UUID()
            projectStatus = outcome.isSuccess ? "live" : "error"
            statusLine = buildSuccessLine
            detailLine = outcome.previewURLString
            latestStreamText = outcome.outputPath
            isBackNavigationLocked = false

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
            return "The live site is being built and deployed."
        }
    }

    func handle(_ error: Error, fallback: String) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        statusLine = fallback
        detailLine = message
        latestStreamText = message
        isBackNavigationLocked = false
        activeOperationKind = nil
    }

    func shouldKeepPendingRecord(
        for error: Error,
        operation: BuilderPendingOperationKind
    ) -> Bool {
        guard operation == .generate || operation == .edit else {
            return false
        }

        if error is CancellationError {
            return true
        }

        if let authError = error as? SiteMakerAuthorizationError {
            switch authError {
            case .transport, .invalidResponse:
                return true
            default:
                return false
            }
        }

        if case .stream(let message) = (error as? SiteMakerBuilderError) {
            let normalized = message.trimmed.lowercased()

            if normalized.contains("ended before a completion event arrived")
                || normalized.contains("returned no events")
                || normalized.contains("network")
                || normalized.contains("connection")
                || normalized.contains("timed out")
                || normalized.contains("cancelled")
                || normalized.contains("canceled") {
                return true
            }

            return false
        }

        let fallbackMessage = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            .trimmed
            .lowercased()
        return fallbackMessage.contains("network")
            || fallbackMessage.contains("connection")
            || fallbackMessage.contains("timed out")
            || fallbackMessage.contains("cancelled")
            || fallbackMessage.contains("canceled")
    }

    func isInProgressStatus(_ status: String) -> Bool {
        switch status {
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

    func isTerminalErrorStatus(_ status: String) -> Bool {
        switch status {
        case "error",
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
