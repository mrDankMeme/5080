import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class TranscribeResultSceneViewModel: ObservableObject {
    struct TranscriptRow: Identifiable {
        let id: String
        let timestampText: String?
        let text: String
    }

    struct SummaryTopicRow: Identifiable {
        let id: String
        let title: String
        let text: String
    }

    enum CopyState: Equatable {
        case idle
        case copied
    }

    @Published private(set) var copyState: CopyState = .idle

    let payload: TranscribeResultPayload
    let transcriptRows: [TranscriptRow]
    let summaryRows: [SummaryTopicRow]

    private var copyResetTask: Task<Void, Never>?

    init(payload: TranscribeResultPayload) {
        self.payload = payload

        self.transcriptRows = payload.transcriptSegments.enumerated().map { index, segment in
            TranscriptRow(
                id: "segment_\(index)",
                timestampText: payload.timestampsEnabled ? Self.makeTimestampText(start: segment.start, end: segment.end) : nil,
                text: segment.text
            )
        }

        self.summaryRows = payload.summaryTopics.enumerated().map { index, topic in
            SummaryTopicRow(
                id: "topic_\(index)",
                title: "Topic \(index + 1)",
                text: topic
            )
        }
    }

    deinit {
        copyResetTask?.cancel()
    }

    var sectionTitle: String {
        payload.outputFormat == .summary ? "Summary" : "Full Transcript"
    }

    var fileBaseName: String {
        let value = NSString(string: payload.fileName)
            .deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return value.isEmpty ? "transcription" : value
    }

    var fileExtensionText: String? {
        let value = NSString(string: payload.fileName)
            .pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            return nil
        }

        return ".\(value)"
    }

    var fileIconAssetName: String {
        payload.isVideo ? "tr_video_24" : "tr_audio_24"
    }

    var copyButtonTitle: String {
        copyState == .copied ? "Copied" : "Copy Text"
    }

    var isSummary: Bool {
        payload.outputFormat == .summary
    }

    var formattedExportText: String {
        if payload.outputFormat == .summary {
            if summaryRows.isEmpty {
                return payload.rawResultJSONString
            }

            return summaryRows
                .map { "\($0.title)\n\($0.text)" }
                .joined(separator: "\n\n")
        }

        if transcriptRows.isEmpty {
            return payload.rawResultJSONString
        }

        return transcriptRows
            .map { row in
                if let timestampText = row.timestampText, payload.timestampsEnabled {
                    return "[\(timestampText)]\n\(row.text)"
                }
                return row.text
            }
            .joined(separator: "\n\n")
    }

    func copyText() {
        UIPasteboard.general.string = formattedExportText
        copyState = .copied

        copyResetTask?.cancel()
        copyResetTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            self.copyState = .idle
        }
    }

    private static func makeTimestampText(start: Double, end: Double) -> String {
        let startText = formatClock(start)
        let endText = formatClock(end)
        return "\(startText) - \(endText)"
    }

    private static func formatClock(_ seconds: Double) -> String {
        let normalized = max(0, Int(seconds.rounded(.down)))
        let minutes = normalized / 60
        let secondsPart = normalized % 60
        return String(format: "%02d:%02d", minutes, secondsPart)
    }
}
