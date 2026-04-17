import Foundation
import Combine
import UIKit

@MainActor
final class AnimateImageSceneViewModel: ObservableObject {
    @Published var promptText: String = "" {
        didSet {
            guard promptText.count > Self.promptCharacterLimit else { return }
            promptText = String(promptText.prefix(Self.promptCharacterLimit))
        }
    }
    @Published private(set) var selectedImageData: Data?
    @Published private(set) var availableTokens = 0
    @Published var alertTitle = "Error"
    @Published var alertMessage: String?
    @Published private(set) var generateCost = 1
    @Published private(set) var isCompressingImage = false

    static let defaultAlertTitle = "Error"
    static let promptCharacterLimit = 2_500
    nonisolated private static let maxUploadBytes = 300_000
    nonisolated private static let minImageDimension: CGFloat = 96
    private var activeCompressionTasks = 0

    var isGenerateEnabled: Bool {
        selectedImageData != nil && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var formattedTokens: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: availableTokens)) ?? "\(availableTokens)"
    }

    func setSelectedImageData(_ data: Data?) {
        guard let data else {
            selectedImageData = nil
            return
        }

        selectedImageData = Self.normalizedUploadData(from: data)
    }

    func prepareSelectedImageData(_ data: Data?) async {
        guard let data else {
            selectedImageData = nil
            return
        }

        guard data.count >= Self.maxUploadBytes else {
            selectedImageData = data
            return
        }

        beginCompression()
        defer { endCompression() }

        let normalized = await Task.detached(priority: .userInitiated) {
            Self.normalizedUploadData(from: data)
        }.value

        selectedImageData = normalized
    }

    func removeSelectedImage() {
        selectedImageData = nil
    }

    func setPrompt(_ prompt: String) {
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

    private func beginCompression() {
        activeCompressionTasks += 1
        isCompressingImage = activeCompressionTasks > 0
    }

    private func endCompression() {
        activeCompressionTasks = max(0, activeCompressionTasks - 1)
        isCompressingImage = activeCompressionTasks > 0
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
