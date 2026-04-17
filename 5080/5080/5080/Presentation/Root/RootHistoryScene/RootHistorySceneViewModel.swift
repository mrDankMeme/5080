import Combine
import Foundation

@MainActor
final class RootHistorySceneViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case video
        case image
        case voice
        case transcript

        var id: String { rawValue }
    }

    struct FilterChip: Identifiable {
        let filter: Filter
        let title: String
        let systemImageName: String?
        let assetImageName: String?

        var id: String { filter.id }
    }

    struct EntryItem: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let flowKind: HistoryFlowKind
        let status: HistoryEntryStatus
        let createdAt: Date
        let mediaURL: URL?
        let transcribePayload: HistoryTranscribePayload?
    }

    struct SectionModel: Identifiable {
        let id: String
        let title: String
        let items: [EntryItem]
    }

    struct ResultDestination: Identifiable {
        enum Kind {
            case video(URL)
            case image(URL)
            case voice(URL, String)
            case transcript(TranscribeResultPayload)
        }

        let id = UUID()
        let kind: Kind
    }

    @Published var selectedFilter: Filter = .all {
        didSet { rebuildSections() }
    }
    @Published private(set) var filterChips: [FilterChip] = []
    @Published private(set) var sections: [SectionModel] = []
    @Published private(set) var hasAnyEntries = false

    @Published private(set) var menuEntryID: UUID?
    @Published private(set) var menuEntry: EntryItem?

    @Published private(set) var isDeleteDialogPresented = false
    @Published private(set) var isRenameDialogPresented = false
    @Published var renameDraft = ""
    @Published private(set) var renameValidationMessage: String?

    @Published private(set) var isSharePresented = false
    @Published private(set) var shareItems: [Any] = []

    @Published var resultDestination: ResultDestination?

    private let historyRepository: HistoryRepository
    private var entries: [HistoryEntry] = []
    private var entriesByID: [UUID: HistoryEntry] = [:]
    private var renameTargetID: UUID?
    private var deleteTargetID: UUID?
    private var cancellables = Set<AnyCancellable>()
    private var isBound = false

    private var onCreateNew: (() -> Void)?
    private var onRetryFlow: ((HistoryFlowKind) -> Void)?

    init(historyRepository: HistoryRepository) {
        self.historyRepository = historyRepository
        self.filterChips = Self.makeFilterChips()
        bindIfNeeded()
    }

    func configureCallbacks(
        onCreateNew: @escaping () -> Void,
        onRetryFlow: @escaping (HistoryFlowKind) -> Void
    ) {
        self.onCreateNew = onCreateNew
        self.onRetryFlow = onRetryFlow
    }

    func onAppear() {
        bindIfNeeded()
    }

    func tapCreateNew() {
        onCreateNew?()
    }

    func selectFilter(_ filter: Filter) {
        selectedFilter = filter
    }

    func tapEntry(_ item: EntryItem) {
        guard menuEntryID == nil, !isDeleteDialogPresented, !isRenameDialogPresented else { return }

        switch item.status {
        case .processing:
            return

        case .failed:
            onRetryFlow?(item.flowKind)

        case .ready:
            openResult(for: item)
        }
    }

    func openContextMenu(for entryID: UUID) {
        guard let item = sections.flatMap(\.items).first(where: { $0.id == entryID }) else { return }
        menuEntryID = entryID
        menuEntry = item
    }

    func dismissContextMenu() {
        menuEntryID = nil
        menuEntry = nil
    }

    func dismissAllPopups() {
        dismissContextMenu()
        dismissDeleteDialog()
        dismissRenameDialog()
    }

    func tapShareFromMenu() {
        guard let item = menuEntry else { return }
        dismissContextMenu()

        if item.flowKind == .transcribe, let payload = item.transcribePayload {
            shareItems = [formattedTranscribeShareText(payload)]
        } else if let mediaURL = item.mediaURL {
            shareItems = [mediaURL]
        } else {
            shareItems = [item.title]
        }

        isSharePresented = true
    }

    func dismissShareSheet() {
        isSharePresented = false
        shareItems = []
    }

    func tapRenameFromMenu() {
        guard let item = menuEntry else { return }
        dismissContextMenu()

        renameTargetID = item.id
        renameDraft = item.title
        renameValidationMessage = nil
        isRenameDialogPresented = true
    }

    func updateRenameDraft(_ value: String) {
        renameDraft = value
        if renameValidationMessage != nil {
            renameValidationMessage = nil
        }
    }

    func saveRename() {
        guard let targetID = renameTargetID else {
            dismissRenameDialog()
            return
        }

        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameValidationMessage = "Invalid file name"
            return
        }

        do {
            try historyRepository.renameEntry(id: targetID, newTitle: trimmed)
            dismissRenameDialog()
        } catch {
            renameValidationMessage = "Invalid file name"
        }
    }

    func dismissRenameDialog() {
        isRenameDialogPresented = false
        renameDraft = ""
        renameTargetID = nil
        renameValidationMessage = nil
    }

    func tapDeleteFromMenu() {
        guard let item = menuEntry else { return }
        dismissContextMenu()
        deleteTargetID = item.id
        isDeleteDialogPresented = true
    }

    func confirmDelete() {
        guard let id = deleteTargetID else {
            dismissDeleteDialog()
            return
        }

        historyRepository.deleteEntry(id: id)
        dismissDeleteDialog()
    }

    func dismissDeleteDialog() {
        isDeleteDialogPresented = false
        deleteTargetID = nil
    }

    func dismissResultDestination() {
        resultDestination = nil
    }

    private func bindIfNeeded() {
        guard !isBound else { return }
        isBound = true

        historyRepository.entriesPublisher
            .sink { [weak self] incoming in
                guard let self else { return }
                self.entries = incoming
                self.entriesByID = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, $0) })
                self.hasAnyEntries = !incoming.isEmpty
                self.rebuildSections()
            }
            .store(in: &cancellables)
    }

    private func rebuildSections() {
        let filteredEntries = entries.filter { entry in
            switch selectedFilter {
            case .all:
                return true
            case .video:
                return entry.flowKind.category == .video
            case .image:
                return entry.flowKind.category == .image
            case .voice:
                return entry.flowKind.category == .voice
            case .transcript:
                return entry.flowKind.category == .transcript
            }
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        let sortedDays = grouped.keys.sorted(by: >)
        sections = sortedDays.map { day in
            let rows = (grouped[day] ?? [])
                .sorted(by: { $0.createdAt > $1.createdAt })
                .map(makeItem(from:))

            return SectionModel(
                id: ISO8601DateFormatter().string(from: day),
                title: sectionTitle(for: day, calendar: calendar),
                items: rows
            )
        }

        if let menuEntryID, entriesByID[menuEntryID] == nil {
            dismissContextMenu()
        } else if let menuEntryID,
                  let refreshed = sections.flatMap(\.items).first(where: { $0.id == menuEntryID }) {
            menuEntry = refreshed
        }

        if let deleteTargetID, entriesByID[deleteTargetID] == nil {
            dismissDeleteDialog()
        }

        if let renameTargetID, entriesByID[renameTargetID] == nil {
            dismissRenameDialog()
        }
    }

    private func makeItem(from entry: HistoryEntry) -> EntryItem {
        let subtitle: String

        switch entry.status {
        case .processing:
            subtitle = "Processing..."
        case .failed:
            subtitle = "Generation failed. Tap to retry."
        case .ready:
            subtitle = "\(Self.timeFormatter.string(from: entry.createdAt)) • \(typeText(for: entry))"
        }

        return EntryItem(
            id: entry.id,
            title: entry.title,
            subtitle: subtitle,
            flowKind: entry.flowKind,
            status: entry.status,
            createdAt: entry.createdAt,
            mediaURL: historyRepository.mediaURL(for: entry),
            transcribePayload: entry.transcribePayload
        )
    }

    private func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }

        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }

        return Self.dayFormatter.string(from: day)
    }

    private func typeText(for entry: HistoryEntry) -> String {
        switch entry.flowKind {
        case .textToVideo, .animateImage, .frameToVideo:
            return "Video"
        case .aiImage:
            return "Image"
        case .voiceGen:
            return "Voice"
        case .transcribe:
            if entry.transcribePayload?.isVideo == true {
                return "Video to Text"
            }
            return "Audio to Text"
        }
    }

    private func openResult(for item: EntryItem) {
        switch item.flowKind {
        case .textToVideo, .animateImage, .frameToVideo:
            guard let mediaURL = item.mediaURL else { return }
            resultDestination = ResultDestination(kind: .video(mediaURL))

        case .aiImage:
            guard let mediaURL = item.mediaURL else { return }
            resultDestination = ResultDestination(kind: .image(mediaURL))

        case .voiceGen:
            guard let mediaURL = item.mediaURL else { return }
            resultDestination = ResultDestination(kind: .voice(mediaURL, item.title))

        case .transcribe:
            guard let payload = item.transcribePayload else { return }
            resultDestination = ResultDestination(
                kind: .transcript(
                    TranscribeResultPayload(
                        fileName: payload.fileName,
                        isVideo: payload.isVideo,
                        outputFormat: payload.outputFormat == .summary ? .summary : .fullText,
                        timestampsEnabled: payload.timestampsEnabled,
                        transcriptSegments: payload.transcriptSegments.map {
                            TranscribeTranscriptSegment(text: $0.text, start: $0.start, end: $0.end)
                        },
                        summaryTopics: payload.summaryTopics,
                        rawResultJSONString: payload.rawResultJSONString
                    )
                )
            )
        }
    }

    private func formattedTranscribeShareText(_ payload: HistoryTranscribePayload) -> String {
        if payload.outputFormat == .summary {
            let summary = payload.summaryTopics.enumerated().map { index, topic in
                "Topic \(index + 1)\n\(topic)"
            }.joined(separator: "\n\n")

            if summary.isEmpty {
                return payload.rawResultJSONString
            }

            return summary
        }

        let transcript = payload.transcriptSegments.map { segment -> String in
            if payload.timestampsEnabled {
                return "[\(Self.timestampText(start: segment.start, end: segment.end))]\n\(segment.text)"
            }
            return segment.text
        }.joined(separator: "\n\n")

        return transcript.isEmpty ? payload.rawResultJSONString : transcript
    }

    private static func timestampText(start: Double, end: Double) -> String {
        "\(clockText(start)) - \(clockText(end))"
    }

    private static func clockText(_ seconds: Double) -> String {
        let normalized = max(0, Int(seconds.rounded(.down)))
        let minutes = normalized / 60
        let secondsPart = normalized % 60
        return String(format: "%02d:%02d", minutes, secondsPart)
    }

    private static func makeFilterChips() -> [FilterChip] {
        [
            FilterChip(filter: .all, title: "All", systemImageName: nil, assetImageName: nil),
            FilterChip(filter: .video, title: "Video", systemImageName: "video", assetImageName: "history_video_24"),
            FilterChip(filter: .image, title: "Image", systemImageName: "photo", assetImageName: "history_image_24"),
            FilterChip(filter: .voice, title: "Voice", systemImageName: "waveform", assetImageName: "history_voice_24"),
            FilterChip(filter: .transcript, title: "Transcript", systemImageName: "mic", assetImageName: "history_transcript_24")
        ]
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
