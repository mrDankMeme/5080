import Foundation
import Combine

@MainActor
final class AIImageSceneViewModel: ObservableObject {
    enum AspectRatio: String, CaseIterable, Identifiable {
        case ratio9x16 = "9:16"

        var id: String { rawValue }

        var sizeValue: String? {
            "1024x1536"
        }
    }

    enum Quality: String, CaseIterable, Identifiable {
        case auto = "auto"

        var id: String { displayTitle }

        var displayTitle: String {
            "Auto"
        }

        var requestValue: String {
            rawValue
        }
    }

    @Published var promptText: String = "" {
        didSet {
            guard promptText.count > Self.promptCharacterLimit else { return }
            promptText = String(promptText.prefix(Self.promptCharacterLimit))
        }
    }
    @Published var isSettingsPresented = false
    @Published var selectedAspectRatio: AspectRatio = .ratio9x16
    @Published var selectedQuality: Quality = .auto
    @Published private(set) var availableTokens = 0
    @Published private(set) var selectedInspirationID: String?
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?
    @Published private(set) var generateCost = 1

    let inspirationCards: [AIImageInspirationCard]

    static let defaultAlertTitle = "Error"
    static let promptCharacterLimit = 2_500

    init(inspirationCards: [AIImageInspirationCard]) {
        self.inspirationCards = inspirationCards
    }

    convenience init() {
        self.init(inspirationCards: AIImageInspirationCatalog.cards)
    }

    var isGenerateEnabled: Bool {
        !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    func applyInspiration(_ card: AIImageInspirationCard) {
        selectedInspirationID = card.id
        promptText = card.prompt
    }

    func setPrompt(_ prompt: String) {
        selectedInspirationID = nil
        promptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateGenerateCost(_ value: Int) {
        generateCost = max(1, value)
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
