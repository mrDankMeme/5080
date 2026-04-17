import Foundation
import Combine

@MainActor
final class TranscribeSceneViewModel: ObservableObject {
    enum SourceLanguage: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case english = "English"
        case russian = "Russian"
        case spanish = "Spanish"

        var id: String { rawValue }
    }

    enum OutputFormat: String, CaseIterable, Identifiable {
        case fullText = "Full Text"
        case summary = "Summary"

        var id: String { rawValue }

        var requestValue: TranscribeOutputFormat {
            switch self {
            case .fullText:
                return .fullText
            case .summary:
                return .summary
            }
        }
    }

    enum TimestampsMode: String, CaseIterable, Identifiable {
        case on = "On"
        case off = "Off"

        var id: String { rawValue }

        var isEnabled: Bool {
            self == .on
        }
    }

    @Published var isSettingsPresented = false
    @Published var selectedSourceLanguage: SourceLanguage = .auto
    @Published var selectedOutputFormat: OutputFormat = .fullText
    @Published var selectedTimestampsMode: TimestampsMode = .on
    @Published private(set) var selectedMedia: TranscribeSelectedMedia?
    @Published private(set) var availableTokens = 0
    @Published private(set) var transcribeCost = 1
    @Published private(set) var isPreparingSelection = false
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?

    static let defaultAlertTitle = "Error"
    var isTranscribeEnabled: Bool {
        selectedMedia != nil && !isPreparingSelection
    }

    var uploadButtonTitle: String {
        selectedMedia?.fileName ?? "Upload Audio or Video"
    }

    var uploadButtonBaseName: String {
        guard let fileName = selectedMedia?.fileName else {
            return "Upload Audio or Video"
        }

        let base = NSString(string: fileName)
            .deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return base.isEmpty ? fileName : base
    }

    var uploadButtonExtensionText: String? {
        guard let fileName = selectedMedia?.fileName else {
            return nil
        }

        let fileExtension = NSString(string: fileName)
            .pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fileExtension.isEmpty else {
            return nil
        }

        return ".\(fileExtension)"
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    func beginPreparingSelection() {
        isPreparingSelection = true
    }

    func endPreparingSelection() {
        isPreparingSelection = false
    }

    func setSelectedMedia(_ media: TranscribeSelectedMedia?) {
        selectedMedia = media
    }

    func clearSelectedMedia() {
        selectedMedia = nil
    }

    func updateTranscribeCost(_ cost: Int) {
        transcribeCost = max(1, cost)
    }

    func syncAvailableTokens(_ value: Int) {
        availableTokens = max(0, value)
    }

    func showError(_ message: String) {
        showAlert(title: Self.defaultAlertTitle, message: message)
    }

    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
    }

    func clearError() {
        alertTitle = Self.defaultAlertTitle
        alertMessage = nil
    }
}
