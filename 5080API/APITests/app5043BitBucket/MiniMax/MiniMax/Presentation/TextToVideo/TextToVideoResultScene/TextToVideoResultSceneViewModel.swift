import Foundation
import Combine
import Photos
import SwiftUI

@MainActor
final class TextToVideoResultSceneViewModel: ObservableObject {
    enum SaveState: Equatable {
        case download
        case saving(dotCount: Int)
        case saved
    }

    enum SaveToast: Equatable {
        case saved
        case failed
    }

    @Published private(set) var saveState: SaveState = .download
    @Published private(set) var toast: SaveToast?

    let videoURL: URL

    private var saveTask: Task<Void, Never>?
    private var dotsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init(videoURL: URL) {
        self.videoURL = videoURL
    }

    deinit {
        saveTask?.cancel()
        dotsTask?.cancel()
        toastTask?.cancel()
    }

    var saveButtonTitle: String {
        switch saveState {
        case .download:
            return "Download"
        case .saving(let dotCount):
            let dots = String(repeating: ".", count: max(1, min(3, dotCount)))
            return "Saving\(dots)"
        case .saved:
            return "Saved"
        }
    }

    var isSaveDisabled: Bool {
        if case .saving = saveState {
            return true
        }
        return false
    }

    var saveButtonOpacity: CGFloat {
        switch saveState {
        case .saving:
            return 0.5
        default:
            return 1.0
        }
    }

    func saveToGallery() {
        guard !isSaveDisabled else { return }

        saveTask?.cancel()
        dotsTask?.cancel()

        saveState = .saving(dotCount: 1)
        startDotsAnimation()

        saveTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.performSaveToGallery()
                self.dotsTask?.cancel()
                self.saveState = .saved
                self.showToast(.saved)
            } catch {
                self.dotsTask?.cancel()
                self.saveState = .download
                self.showToast(.failed)
            }
        }
    }

    private func startDotsAnimation() {
        dotsTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }

                if case .saving(let dotCount) = self.saveState {
                    let next = dotCount % 3 + 1
                    self.saveState = .saving(dotCount: next)
                }
            }
        }
    }

    private func showToast(_ toast: SaveToast) {
        toastTask?.cancel()
        self.toast = toast

        toastTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.toast = nil
            }
        }
    }

    private func performSaveToGallery() async throws {
        let authorization = await requestGalleryAccess()
        guard authorization == .authorized || authorization == .limited else {
            throw APIError.backendMessage("Photo library access is denied")
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoURL)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: error ?? APIError.backendMessage("Failed to save video"))
                }
            }
        }
    }

    private func requestGalleryAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch current {
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        default:
            return current
        }
    }
}
