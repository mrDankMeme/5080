import Foundation
import Combine

@MainActor
final class VoiceGenSceneViewModel: ObservableObject {
    enum VoiceSkin: String, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"
        case robot = "Robot"
        case kid = "Kid"

        var id: String { rawValue }

        var requestValue: String {
            rawValue.lowercased()
        }
    }

    enum Speed: String, CaseIterable, Identifiable {
        case x08 = "0.8x"
        case x10 = "1.0x"
        case x12 = "1.2x"
        case x15 = "1.5x"

        var id: String { rawValue }

        var requestValue: String {
            rawValue.replacingOccurrences(of: "x", with: "")
        }
    }

    enum Tone: String, CaseIterable, Identifiable {
        case neutral = "Neutral"
        case happy = "Happy"
        case serious = "Serious"
        case whisper = "Whisper"

        var id: String { rawValue }

        var requestValue: String {
            rawValue.lowercased()
        }
    }

    @Published var promptText: String = "" {
        didSet {
            guard promptText.count > Self.promptCharacterLimit else { return }
            promptText = String(promptText.prefix(Self.promptCharacterLimit))
        }
    }
    @Published var isSettingsPresented = false
    @Published var selectedVoiceSkin: VoiceSkin = .male
    @Published var selectedSpeed: Speed = .x10
    @Published var selectedTone: Tone = .neutral
    @Published private(set) var availableTokens = 0
    @Published private(set) var generateCost = 1
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?

    static let defaultAlertTitle = "Error"
    static let promptCharacterLimit = 2_500

    var isGenerateEnabled: Bool {
        !effectiveScriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    var effectiveScriptText: String {
        promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makePromptForRequest() -> String {
        effectiveScriptText
    }

    func updateGenerateCost(_ cost: Int) {
        generateCost = max(1, cost)
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
