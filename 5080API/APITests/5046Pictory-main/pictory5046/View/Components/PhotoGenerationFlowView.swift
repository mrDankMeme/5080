import SwiftUI
import SwiftData

struct PhotoGenerationFlowView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager

    enum Phase: Equatable {
        case creating
        case result(UIImage)
    }

    let resultId: UUID
    let jobId: String
    let generationType: GenerateType
    let onError: (Error) -> Void

    @State private var phase: Phase = .creating

    var body: some View {
        ZStack {
            switch phase {
            case .creating:
                GenerationView(
                    isVideo: false,
                    jobId: jobId,
                    onComplete: { image in
                        handleComplete(image: image)
                    },
                    onError: { error in
                        handleError(error)
                    }
                )
            case .result(let image):
                GeneratedPhotoView(img: image)
            }
        }
        .animation(.interpolatingSpring(duration: 0.35), value: phase)
    }

    private func handleComplete(image: UIImage) {
        do {
            guard let resultData = image.jpegData(compressionQuality: 0.9) else {
                throw GenerationStatusError.invalidImageData
            }

            let descriptor = FetchDescriptor<TemplateResult>(
                predicate: #Predicate { $0.id == resultId }
            )
            guard let item = try modelContext.fetch(descriptor).first else {
                throw GenerationStatusError.noData
            }

            item.resultImageData = resultData
            item.isVideoResult = false
            item.resultVideoLocalPath = nil
            item.generationTypeRaw = generationType.rawValue
            item.generationStatusRaw = TemplateResultStatus.completed.rawValue
            item.generationErrorMessage = nil

            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
            Task {
                await apiManager.authorize()
            }

            withAnimation(.interpolatingSpring(duration: 0.35)) {
                phase = .result(image)
            }
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        let descriptor = FetchDescriptor<TemplateResult>(
            predicate: #Predicate { $0.id == resultId }
        )
        if let item = try? modelContext.fetch(descriptor).first {
            item.generationStatusRaw = TemplateResultStatus.failed.rawValue
            item.generationErrorMessage = error.localizedDescription
            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
        }
        Task {
            await apiManager.authorize()
        }
        onError(error)
        dismiss()
    }
}
