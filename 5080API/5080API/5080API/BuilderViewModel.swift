import Combine
import Foundation

@MainActor
final class BuilderViewModel: ObservableObject {
    @Published var composerText = ""
    @Published var shareSheetPayload: BuilderShareSheetPayload?
    @Published private(set) var promptText = ""
    @Published private(set) var questions: [BuilderQuestion] = []
    @Published private(set) var briefDescription = ""
    @Published private(set) var suggestedTheme = ""
    @Published private(set) var suggestedPalette = ""
    @Published private(set) var projectID: String?
    @Published private(set) var projectSlug: String?
    @Published private(set) var projectStatus = "idle"
    @Published private(set) var previewURL: URL?
    @Published private(set) var previewReloadKey = UUID()
    @Published private(set) var statusLine = "Type a prompt below and tap the plane to fetch real clarify questions."
    @Published private(set) var detailLine = "Generate will stay disabled until clarify completes."
    @Published private(set) var latestStreamText = "No stream yet."
    @Published private(set) var isBusy = false

    private let service: SiteMakerBuilderService

    init(service: SiteMakerBuilderService? = nil) {
        self.service = service ?? SiteMakerBuilderService()
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

    var sendPlaceholder: String {
        hasPreview ? "Describe the edits you want to apply..." : "Describe what you want to create..."
    }

    var sendButtonAccessibilityLabel: String {
        hasPreview ? "Apply edit" : "Clarify prompt"
    }

    var canSharePreview: Bool {
        previewURL != nil && !isBusy
    }

    var canExportSource: Bool {
        projectID != nil && hasPreview && !isBusy
    }

    func resetFlow() {
        guard !isBusy else { return }

        composerText = ""
        promptText = ""
        questions = []
        briefDescription = ""
        suggestedTheme = ""
        suggestedPalette = ""
        projectID = nil
        projectSlug = nil
        projectStatus = "idle"
        previewURL = nil
        previewReloadKey = UUID()
        latestStreamText = "No stream yet."
        statusLine = "Builder reset. Type a fresh prompt and tap the plane."
        detailLine = "A new project will be created automatically on the next clarify call."
    }

    func dismissShareSheet() {
        shareSheetPayload = nil
    }

    func updateSelection(questionID: String, selectedIndex: Int) {
        guard let index = questions.firstIndex(where: { $0.id == questionID }) else { return }
        questions[index].selectedIndex = selectedIndex
    }

    func submitComposer() async {
        let text = composerText.trimmed
        guard !text.isEmpty else {
            handle(BuilderFlowError.emptyPrompt, fallback: "Prompt is empty.")
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
            let auth = try authContext()
            guard let projectID else {
                throw BuilderFlowError.missingProject
            }
            guard hasQuestions, !briefDescription.isEmpty else {
                throw BuilderFlowError.missingClarifyResult
            }

            isBusy = true
            statusLine = "Generating site..."
            detailLine = "Spec, code, files, and build events will stream from the backend."
            latestStreamText = "Waiting for spec stream..."

            let enrichedPrompt = buildEnrichedPrompt()

            try await service.streamGenerate(
                baseURLString: auth.baseURLString,
                authToken: auth.accessToken,
                projectID: projectID,
                prompt: enrichedPrompt
            ) { [weak self] event in
                self?.handleGenerateEvent(event)
            }

            if previewURL == nil {
                statusLine = "Generate finished without a preview URL."
                detailLine = "Check the backend stream logs for the final event payload."
            }
        } catch {
            handle(error, fallback: "Generate failed.")
        }

        isBusy = false
    }

    func sharePreviewLink() {
        do {
            guard let previewURL else {
                throw BuilderFlowError.missingPreviewURL
            }

            shareSheetPayload = BuilderShareSheetPayload(
                items: [previewURL],
                subject: "Site Preview"
            )
            statusLine = "Preview link ready to share."
            detailLine = previewURL.absoluteString
        } catch {
            handle(error, fallback: "Preview share failed.")
        }
    }

    func exportSourceFiles() async {
        do {
            let auth = try authContext()
            guard let projectID else {
                throw BuilderFlowError.missingProject
            }

            isBusy = true
            statusLine = "Preparing source export..."
            detailLine = "Fetching project files from the backend."

            let project = try await service.fetchProject(
                baseURLString: auth.baseURLString,
                authToken: auth.accessToken,
                projectID: projectID
            )

            guard let currentFiles = project.current_files, !currentFiles.trimmed.isEmpty else {
                throw BuilderFlowError.missingCurrentFiles
            }

            let files = try decodeProjectFiles(from: currentFiles)
            let exportURL = try writeExportDirectory(files: files, slug: project.slug)

            shareSheetPayload = BuilderShareSheetPayload(
                items: [exportURL],
                subject: "\(project.name) Source Files"
            )
            statusLine = "Source files ready to share."
            detailLine = "Export contains \(files.count) files."
            latestStreamText = exportURL.lastPathComponent
        } catch {
            handle(error, fallback: "Source export failed.")
        }

        isBusy = false
    }

    private func clarify(prompt: String) async {
        do {
            let auth = try authContext()

            isBusy = true
            statusLine = "Preparing project..."
            detailLine = "Creating a draft project before clarify."
            latestStreamText = "Waiting for clarify stream..."
            previewURL = nil
            projectStatus = "draft"

            let projectID = try await ensureProject(prompt: prompt, auth: auth)

            promptText = prompt
            questions = []
            briefDescription = ""
            suggestedTheme = ""
            suggestedPalette = ""

            try await service.streamClarify(
                baseURLString: auth.baseURLString,
                authToken: auth.accessToken,
                projectID: projectID,
                prompt: prompt
            ) { [weak self] event in
                self?.handleClarifyEvent(event)
            }
        } catch {
            handle(error, fallback: "Clarify failed.")
        }

        isBusy = false
    }

    private func applyEdit(instruction: String) async {
        do {
            let auth = try authContext()
            guard let projectID else {
                throw BuilderFlowError.missingProject
            }

            isBusy = true
            statusLine = "Applying edit..."
            detailLine = "Editing the generated site and rebuilding preview."
            latestStreamText = instruction

            try await service.streamEdit(
                baseURLString: auth.baseURLString,
                authToken: auth.accessToken,
                projectID: projectID,
                instruction: instruction
            ) { [weak self] event in
                self?.handleEditEvent(event)
            }

            if previewURL == nil {
                statusLine = "Edit finished without a preview URL."
                detailLine = "Check the backend stream logs for the final event payload."
            }
        } catch {
            handle(error, fallback: "Edit failed.")
        }

        isBusy = false
    }

    private func ensureProject(prompt: String, auth: AuthContext) async throws -> String {
        if let projectID {
            return projectID
        }

        let project = try await service.createProject(
            baseURLString: auth.baseURLString,
            authToken: auth.accessToken,
            prompt: prompt
        )

        self.projectID = project.id
        self.projectSlug = project.slug
        self.projectStatus = project.status
        self.statusLine = "Project created."
        self.detailLine = "Project \(project.slug) is ready for clarify."

        return project.id
    }

    private func handleClarifyEvent(_ event: SiteMakerSSEEvent) {
        switch event.event {
        case "clarify_start":
            statusLine = decodeString(from: event.data) ?? "Analyzing your idea..."
            detailLine = "The backend is writing a richer brief and question set."
        case "clarify_token":
            latestStreamText = decodeString(from: event.data) ?? event.data
        case "clarify_complete":
            if let brief = decode(SiteMakerClarifyResponse.self, from: event.data) {
                briefDescription = brief.description
                suggestedTheme = brief.suggested_theme
                suggestedPalette = brief.suggested_palette
                questions = brief.questions.map { question in
                    BuilderQuestion(
                        id: question.id,
                        title: question.question,
                        options: question.options,
                        selectedIndex: question.default.clamped(to: 0...(max(0, question.options.count - 1)))
                    )
                }
                statusLine = "Clarify complete."
                detailLine = "Pick options and tap Generate Site."
                latestStreamText = brief.description
            } else {
                latestStreamText = event.data
            }
        default:
            latestStreamText = event.data
        }
    }

    private func handleGenerateEvent(_ event: SiteMakerSSEEvent) {
        switch event.event {
        case "spec_start", "code_start", "build_start":
            statusLine = decodeString(from: event.data) ?? fallbackLabel(for: event.event)
            detailLine = detailMessage(for: event.event)
        case "spec_token", "code_token":
            latestStreamText = decodeString(from: event.data) ?? event.data
        case "spec_complete", "code_complete":
            latestStreamText = decodeString(from: event.data) ?? fallbackLabel(for: event.event)
        case "files_written":
            if let written = decode(SiteMakerFilesWritten.self, from: event.data) {
                let count = written.file_count ?? written.files?.count ?? written.changed_files?.count ?? 0
                statusLine = "Files written."
                detailLine = "Backend wrote \(count) files."
                latestStreamText = "duration_ms: \(written.duration_ms ?? 0)"
            }
        case "build_complete":
            applyBuildComplete(from: event.data, successLine: "Site is live.")
        default:
            latestStreamText = event.data
        }
    }

    private func handleEditEvent(_ event: SiteMakerSSEEvent) {
        switch event.event {
        case "code_start", "build_start":
            statusLine = decodeString(from: event.data) ?? fallbackLabel(for: event.event)
            detailLine = detailMessage(for: event.event)
        case "code_token":
            latestStreamText = decodeString(from: event.data) ?? event.data
        case "code_complete":
            latestStreamText = decodeString(from: event.data) ?? "Edit complete"
        case "files_written":
            if let written = decode(SiteMakerFilesWritten.self, from: event.data) {
                let count = written.file_count ?? written.changed_files?.count ?? written.files?.count ?? 0
                statusLine = "Edit files written."
                detailLine = "Backend changed \(count) files."
                latestStreamText = "duration_ms: \(written.duration_ms ?? 0)"
            }
        case "build_complete":
            applyBuildComplete(from: event.data, successLine: "Preview updated.")
        default:
            latestStreamText = event.data
        }
    }

    private func applyBuildComplete(from rawData: String, successLine: String) {
        guard let buildComplete = decode(SiteMakerBuildComplete.self, from: rawData) else {
            latestStreamText = rawData
            return
        }

        if let url = URL(string: buildComplete.preview_url) {
            previewURL = url
            previewReloadKey = UUID()
        }

        projectStatus = buildComplete.build.success ? "live" : "error"
        statusLine = successLine
        detailLine = buildComplete.preview_url
        latestStreamText = buildComplete.build.output_path
    }

    private func buildEnrichedPrompt() -> String {
        let preferenceLines = questions.map { question in
            let option = question.options[safe: question.selectedIndex] ?? question.options.first ?? "-"
            return "\(question.title) -> \(option)"
        }

        let preferencesText = preferenceLines.joined(separator: "\n")

        return """
        Original request: \(promptText)

        Design brief: \(briefDescription)

        Suggested theme: \(suggestedTheme)
        Suggested palette: \(suggestedPalette)

        Design preferences:
        \(preferencesText)
        """
    }

    private func decodeProjectFiles(from rawJSON: String) throws -> [String: String] {
        guard let data = rawJSON.data(using: .utf8) else {
            throw BuilderFlowError.missingCurrentFiles
        }

        if let files = try? JSONDecoder().decode([String: String].self, from: data) {
            return files
        }

        guard
            let nestedJSONString = try? JSONDecoder().decode(String.self, from: data),
            let nestedData = nestedJSONString.data(using: .utf8),
            let files = try? JSONDecoder().decode([String: String].self, from: nestedData)
        else {
            throw BuilderFlowError.missingCurrentFiles
        }

        return files
    }

    private func writeExportDirectory(files: [String: String], slug: String) throws -> URL {
        let fileManager = FileManager.default
        let rootDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("5080Exports", isDirectory: true)
            .appendingPathComponent("\(slug)-source", isDirectory: true)

        if fileManager.fileExists(atPath: rootDirectory.path) {
            try fileManager.removeItem(at: rootDirectory)
        }

        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        for (relativePath, content) in files {
            let destinationURL = rootDirectory.appendingPathComponent(relativePath, isDirectory: false)
            let parentDirectory = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            try content.write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        if let previewURL {
            let readmeURL = rootDirectory.appendingPathComponent("README.txt")
            let readme = """
            Exported from 5080API

            Preview URL:
            \(previewURL.absoluteString)

            Files:
            \(files.keys.sorted().joined(separator: "\n"))
            """
            try readme.write(to: readmeURL, atomically: true, encoding: .utf8)
        }

        return rootDirectory
    }

    private func authContext() throws -> AuthContext {
        let session = AuthLabStorage.load()
        let baseURLString = session.baseURLString.trimmed
        let accessToken = session.accessToken.trimmed

        guard !accessToken.isEmpty else {
            throw BuilderFlowError.missingAccessToken
        }

        return AuthContext(baseURLString: baseURLString, accessToken: accessToken)
    }

    private func decodeString(from rawData: String) -> String? {
        guard let data = rawData.data(using: .utf8) else { return nil }
        if let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }

        return rawData
    }

    private func decode<T: Decodable>(_ type: T.Type, from rawData: String) -> T? {
        guard let data = rawData.data(using: .utf8) else { return nil }
        if let decoded = try? JSONDecoder().decode(type, from: data) {
            return decoded
        }

        guard
            let nestedJSONString = try? JSONDecoder().decode(String.self, from: data),
            let nestedData = nestedJSONString.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: nestedData)
    }

    private func fallbackLabel(for eventName: String) -> String {
        switch eventName {
        case "spec_start":
            return "Generating site specification..."
        case "code_start":
            return "Generating site code..."
        case "build_start":
            return "Building preview..."
        default:
            return eventName
        }
    }

    private func detailMessage(for eventName: String) -> String {
        switch eventName {
        case "spec_start":
            return "The backend is designing the site structure."
        case "code_start":
            return "React + Tailwind files are being generated."
        case "build_start":
            return "The preview is being built and deployed."
        default:
            return "Streaming backend updates..."
        }
    }

    private func handle(_ error: Error, fallback: String) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        statusLine = fallback
        detailLine = message
        latestStreamText = message
    }
}

private struct AuthContext {
    let baseURLString: String
    let accessToken: String
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
