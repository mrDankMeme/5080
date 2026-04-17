import Foundation
import Combine

@MainActor
final class TextToVideoSceneViewModel: ObservableObject {
    enum AspectRatio: String, CaseIterable, Identifiable {
        case ratio9x16 = "9:16"

        var id: String { rawValue }
    }

    enum Resolution: String, CaseIterable, Identifiable {
        case p720 = "720p"
        case p1080 = "1080p"

        var id: String { rawValue }
    }

    enum Duration: String, CaseIterable, Identifiable {
        case s5 = "5s"
        case s10 = "10s"

        var id: String { rawValue }

        var requestValue: String {
            switch self {
            case .s5:
                return "5"
            case .s10:
                return "10"
            }
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
    @Published var selectedResolution: Resolution = .p720
    @Published var selectedDuration: Duration = .s5 {
        didSet {
            refreshGenerateCost()
        }
    }
    @Published private(set) var availableTokens = 0
    @Published private(set) var selectedInspirationID: String?
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?
    @Published private(set) var generateCost = 1

    let inspirationCards: [TextToVideoInspirationCard]

    private var durationPriceMap: [Int: Int] = [:]
    private var fallbackGenerateCost = 1

    static let defaultAlertTitle = "Error"
    static let promptCharacterLimit = 2_500

    init(inspirationCards: [TextToVideoInspirationCard]) {
        self.inspirationCards = inspirationCards
    }

    convenience init() {
        self.init(inspirationCards: TextToVideoInspirationCatalog.cards)
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

    func applyInspiration(_ card: TextToVideoInspirationCard) {
        selectedInspirationID = card.id
        promptText = card.prompt
    }

    func setPrompt(_ prompt: String) {
        selectedInspirationID = nil
        promptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateGeneratePricing(durationPriceMap: [Int: Int], fallbackCost: Int) {
        self.durationPriceMap = durationPriceMap
        self.fallbackGenerateCost = max(1, fallbackCost)
        refreshGenerateCost()
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

    private func refreshGenerateCost() {
        generateCost = max(1, durationPriceMap[selectedDuration.durationValue] ?? fallbackGenerateCost)
    }
}

private extension TextToVideoSceneViewModel.Duration {
    var durationValue: Int {
        switch self {
        case .s5:
            return 5
        case .s10:
            return 10
        }
    }
}
