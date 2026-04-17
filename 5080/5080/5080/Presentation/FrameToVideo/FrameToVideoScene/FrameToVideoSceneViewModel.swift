import Foundation
import Combine
import UIKit

@MainActor
final class FrameToVideoSceneViewModel: ObservableObject {
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

        var secondsValue: Int {
            switch self {
            case .s5:
                return 5
            case .s10:
                return 10
            }
        }
    }

    @Published var promptText: String = "" {
        didSet {
            guard promptText.count > Self.promptCharacterLimit else { return }
            promptText = String(promptText.prefix(Self.promptCharacterLimit))
        }
    }
    @Published private(set) var startFrameData: Data?
    @Published private(set) var endFrameData: Data?
    @Published private(set) var availableTokens = 0
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?
    @Published private(set) var generateCost = 1
    @Published private(set) var isCompressingFrames = false
    @Published var selectedDuration: Duration = .s5 {
        didSet {
            refreshGenerateCost()
        }
    }

    static let defaultAlertTitle = "Error"
    static let promptCharacterLimit = 2_500

    nonisolated private static let maxUploadBytes = 300_000
    nonisolated private static let minImageDimension: CGFloat = 96

    private var durationPriceMap: [Int: Int] = [:]
    private var fallbackGenerateCost = 1
    private var activeCompressionTasks = 0

    var isGenerateEnabled: Bool {
        startFrameData != nil && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    func setStartFrameData(_ data: Data?) {
        guard let data else {
            startFrameData = nil
            return
        }

        startFrameData = Self.normalizedUploadData(from: data)
    }

    func prepareStartFrameData(_ data: Data?) async {
        guard let data else {
            startFrameData = nil
            return
        }

        guard data.count >= Self.maxUploadBytes else {
            startFrameData = data
            return
        }

        beginCompression()
        defer { endCompression() }

        let normalized = await Task.detached(priority: .userInitiated) {
            Self.normalizedUploadData(from: data)
        }.value

        startFrameData = normalized
    }

    func setEndFrameData(_ data: Data?) {
        guard let data else {
            endFrameData = nil
            return
        }

        endFrameData = Self.normalizedUploadData(from: data)
    }

    func prepareEndFrameData(_ data: Data?) async {
        guard let data else {
            endFrameData = nil
            return
        }

        guard data.count >= Self.maxUploadBytes else {
            endFrameData = data
            return
        }

        beginCompression()
        defer { endCompression() }

        let normalized = await Task.detached(priority: .userInitiated) {
            Self.normalizedUploadData(from: data)
        }.value

        endFrameData = normalized
    }

    func removeStartFrame() {
        startFrameData = nil
    }

    func removeEndFrame() {
        endFrameData = nil
    }

    func setPrompt(_ prompt: String) {
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

    private func beginCompression() {
        activeCompressionTasks += 1
        isCompressingFrames = activeCompressionTasks > 0
    }

    private func endCompression() {
        activeCompressionTasks = max(0, activeCompressionTasks - 1)
        isCompressingFrames = activeCompressionTasks > 0
    }

    private func refreshGenerateCost() {
        generateCost = max(1, durationPriceMap[selectedDuration.secondsValue] ?? fallbackGenerateCost)
    }

    nonisolated private static func normalizedUploadData(from originalData: Data) -> Data {
        guard originalData.count >= maxUploadBytes,
              let image = UIImage(data: originalData) else {
            return originalData
        }

        guard let normalized = normalizedJPEGData(from: image) else {
            return originalData
        }
        return normalized
    }

    nonisolated private static func normalizedJPEGData(from image: UIImage) -> Data? {
        var currentImage = image

        for _ in 0..<10 {
            if let data = highestQualityJPEGUnderLimit(from: currentImage) {
                return data
            }

            guard let resized = downscaledImage(from: currentImage, factor: 0.85) else {
                break
            }
            currentImage = resized
        }

        if let lowestQualityData = currentImage.jpegData(compressionQuality: 0.01),
           lowestQualityData.count < maxUploadBytes {
            return lowestQualityData
        }

        return nil
    }

    nonisolated private static func highestQualityJPEGUnderLimit(from image: UIImage) -> Data? {
        guard let minimumQualityData = image.jpegData(compressionQuality: 0.01),
              minimumQualityData.count < maxUploadBytes else {
            return nil
        }

        var bestData: Data? = minimumQualityData
        var lowQuality: CGFloat = 0.01
        var highQuality: CGFloat = 1.0

        for _ in 0..<20 {
            let quality = (lowQuality + highQuality) / 2.0
            guard let candidate = image.jpegData(compressionQuality: quality) else {
                continue
            }

            if candidate.count < maxUploadBytes {
                bestData = candidate
                lowQuality = quality
            } else {
                highQuality = quality
            }
        }

        return bestData
    }

    nonisolated private static func downscaledImage(from image: UIImage, factor: CGFloat) -> UIImage? {
        let oldSize = image.size
        let targetSize = CGSize(
            width: max(minImageDimension, floor(oldSize.width * factor)),
            height: max(minImageDimension, floor(oldSize.height * factor))
        )

        guard targetSize.width < oldSize.width || targetSize.height < oldSize.height else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
