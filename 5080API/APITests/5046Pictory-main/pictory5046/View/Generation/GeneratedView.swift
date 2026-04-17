import SwiftUI
import SwiftData

struct GeneratedView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var result: TemplateResult

    @State private var resultImage: UIImage?
    @State private var resultVideoURL: URL?
    @State private var generationError: String?

    init(result: TemplateResult, mainViewModel: MainViewModel) {
        self.mainViewModel = mainViewModel
        self.result = result
        _resultImage = State(initialValue: result.resultImage)
        _resultVideoURL = State(initialValue: result.resultVideoURL)
    }

    var body: some View {
        Group {
            if result.isVideoResult {
                if let resultVideoURL {
                    GeneratedVideoView(videoURL: resultVideoURL)
                } else {
                    GenerationView(
                        isVideo: true,
                        jobId: result.jobId,
                        onCompletePayload: { payload in
                            saveGeneratedPayload(payload)
                        },
                        onError: { error in
                            handleGenerationError(error)
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                }
            } else {
                if let resultImage {
                    GeneratedPhotoView(img: resultImage)
                } else {
                    GenerationView(
                        isVideo: false,
                        jobId: result.jobId,
                        onComplete: { image in
                            saveGeneratedImage(image)
                        },
                        onError: { error in
                            handleGenerationError(error)
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                }
            }
        }
        .onChange(of: result.resultImageData) { _, _ in
            if let updatedImage = result.resultImage {
                resultImage = updatedImage
            }
        }
        .onChange(of: result.resultVideoLocalPath) { _, _ in
            resultVideoURL = result.resultVideoURL
        }
        .alert("Error", isPresented: .init(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )) {
            Button("OK") { generationError = nil }
        } message: {
            if let generationError {
                Text(generationError)
            }
        }
    }

    private func saveGeneratedImage(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9) {
            result.resultImageData = data
            result.isVideoResult = false
            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
        }
        resultImage = image
    }
    
    private func saveGeneratedPayload(_ payload: GenerationResultPayload) {
        if payload.isVideo {
            do {
                let videoURL = try VideoStorageManager.saveVideo(data: payload.resultData, jobId: result.jobId)
                result.resultVideoLocalPath = videoURL.path
                if let previewData = payload.previewData {
                    result.resultImageData = previewData
                } else if result.resultImageData == nil {
                    result.resultImageData = result.inputPhotoData
                }
                result.isVideoResult = true
                try? modelContext.save()
                mainViewModel.notifyHistoryUpdated()
                resultVideoURL = videoURL
            } catch {
                handleGenerationError(error)
            }
            return
        }
        
        guard let image = UIImage(data: payload.resultData) else {
            handleGenerationError(GenerationStatusError.invalidImageData)
            return
        }
        saveGeneratedImage(image)
    }
    
    private func handleGenerationError(_ error: Error) {
        generationError = error.localizedDescription
        VideoStorageManager.removeVideoIfExists(at: result.resultVideoLocalPath)
        modelContext.delete(result)
        try? modelContext.save()
        mainViewModel.notifyHistoryUpdated()
        dismiss()
    }
}
