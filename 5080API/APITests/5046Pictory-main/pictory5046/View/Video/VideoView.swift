import Combine
import PhotosUI
import SwiftData
import SwiftUI

struct VideoView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var generationSession: GenerateSession?
    @State private var showPaywall: Bool = false
    @State private var showTokensPaywall: Bool = false
    @FocusState private var isPromptFocused: Bool
            
    var body: some View {
        ScrollView {
            VStack {
                VStack {
                    Button {
                        mainViewModel.showVideoGenerationOptionsView.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(mainViewModel.selectedVideoGenerationOption.title)
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .frame(width: 150)
                                .background(RoundedRectangle(cornerRadius: 100).fill(Color.white.opacity(0.08)))
                            
                            Image(systemName: mainViewModel.showVideoGenerationOptionsView ? "chevron.up" : "chevron.down")
                                .foregroundStyle(Color(hex: "#A6A6A6").opacity(0.7))
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 100).fill(Color(hex: "#252525").opacity(0.82)))
                    }
                    
                    VStack {
                        PromptView(text: $mainViewModel.videoPromt, placeholder: "Describe the idea you want to animate")
                            .focused($isPromptFocused)
                        
                        HStack(alignment: .bottom) {
                            if mainViewModel.selectedVideoGenerationOption == .photoToAnimation {
                                PhotosPicker(
                                    selection: $mainViewModel.selectedVideoItem,
                                    matching: .images,
                                    photoLibrary: .shared()
                                ) {
                                    if let image = mainViewModel.selectedVideoImage {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipped()
                                                .frame(width: 78, height: 78)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            Button {
                                                mainViewModel.selectedVideoImage = nil
                                                mainViewModel.selectedVideoItem = nil
                                            } label: {
                                                Image("trash")
                                                    .foregroundColor(Color.white)
                                                    .padding(6)
                                                    .frame(width: 24, height: 24)
                                                    .background(
                                                        UnevenRoundedRectangle(cornerRadii: .init(
                                                            topLeading: 0,
                                                            bottomLeading: 10,
                                                            bottomTrailing: 0,
                                                            topTrailing: 10
                                                        )).fill(Color(hex: "#9D2938"))
                                                    )
                                            }
                                        }
                                    } else {
                                        ZStack {
                                            Image("add.photo")
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                        }
                                        .frame(width: 78, height: 78)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#252525").opacity(0.82)))
                                    }
                                }
                            } else if mainViewModel.selectedVideoGenerationOption == .photosToStoryVideo {
                                TwoImagePickerView(mainViewModel: mainViewModel)
                            }
                            
                            Spacer()
                            
                            MainButton(title: "Generate", isLargeButton: false, cost: cost()) {
                                startGenerate()
                            }
                            .disabled(mainViewModel.isGenerateDisabled)
                            .opacity(mainViewModel.isGenerateDisabled ? 0.5 : 1)
                        }
                    }
                    .padding()
                    .frame(height: 350)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    .padding(.horizontal)
                    
                    VideoActionsView(mainViewModel: mainViewModel)
                        .padding(.horizontal)
                }
                .padding(.top)
                .padding(.bottom)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isPromptFocused = false
        }
        .sheet(isPresented: $mainViewModel.showVideoGenerationOptionsView) {
            VideoGenerationOptionsView(mainViewModel: mainViewModel)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#282828"))
                .presentationDetents([.height(220)])
        }
        .onChange(of: mainViewModel.selectedVideoItem) {
            guard let item = mainViewModel.selectedVideoItem else { return }

            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)
                {
                    mainViewModel.selectedVideoImage = image
                }
            }
        }
        .fullScreenCover(item: $generationSession) { session in
            VideoGenerationFlowView(
                mainViewModel: mainViewModel,
                resultId: session.resultId,
                jobId: session.jobId,
                generationType: session.generationType,
                onError: { error in
                    generationError = error.localizedDescription
                }
            )
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
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showTokensPaywall) {
            TokensPaywallView()
        }
    }
    
    private func cost() -> Int {
        switch mainViewModel.selectedVideoGenerationOption {
        case .photoToAnimation:
            return purchaseManager.generationPrice(for: .animatePhoto)

        case .promptToVideo:
            return purchaseManager.generationVideoPrice(for: .textToVideo)

        case .photosToStoryVideo:
            return purchaseManager.generationVideoPrice(for: .frameVideo)
        }
    }

    private func startGenerate() {
        guard purchaseManager.isSubscribed else {
            showPaywall = true
            return
        }

        switch mainViewModel.selectedVideoGenerationOption {
        case .promptToVideo:
            guard purchaseManager.availableGenerations >= purchaseManager.generationVideoPrice(for: .textToVideo) else {
                showTokensPaywall = true
                return
            }
            
            startVideoGeneration()
        case .photoToAnimation:
            guard purchaseManager.availableGenerations >= purchaseManager.generationPrice(for: .animatePhoto) else {
                showTokensPaywall = true
                return
            }
            
            startAnimatePhoto()
        case .photosToStoryVideo:
            guard purchaseManager.availableGenerations >= purchaseManager.generationVideoPrice(for: .frameVideo) else {
                showTokensPaywall = true
                return
            }
            
            startPhotosToStoryVideoGeneration()
        }
    }
    
    private func startVideoGeneration() {
        let prompt = mainViewModel.videoPromt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.generateVideo(prompt: prompt)
                
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: nil,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.textToVideo.rawValue,
                        isVideoResult: true,
                        resultVideoLocalPath: nil,
                        effectStyleId: 0,
                        effectId: 0,
                        templateTitle: "Video",
                        requestUserId: purchaseManager.userId,
                        requestPrompt: prompt,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .textToVideo)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }
    
    private func startAnimatePhoto() {
        guard let image = mainViewModel.selectedVideoImage,
              let frameData = image.jpegData(compressionQuality: 0.9)
        else { return }
        
        let prompt = mainViewModel.videoPromt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.animatePhoto(prompt: prompt, frameData: frameData)
                
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: frameData,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.animatePhoto.rawValue,
                        isVideoResult: true,
                        resultVideoLocalPath: nil,
                        effectStyleId: 0,
                        effectId: 0,
                        templateTitle: "Animate Photo",
                        requestUserId: purchaseManager.userId,
                        requestPrompt: prompt,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .animatePhoto)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }

    private func startPhotosToStoryVideoGeneration() {
        guard let startImage = mainViewModel.leftVideoImage,
              let endImage = mainViewModel.rightVideoImage,
              let startFrameData = startImage.jpegData(compressionQuality: 0.9),
              let endFrameData = endImage.jpegData(compressionQuality: 0.9) else { return }
        
        let prompt = mainViewModel.videoPromt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.generateFrameVideo(
                    prompt: prompt,
                    startFrameData: startFrameData,
                    endFrameData: endFrameData
                )
                
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: startFrameData,
                        inputPhotoSecondData: endFrameData,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.frameVideo.rawValue,
                        isVideoResult: true,
                        resultVideoLocalPath: nil,
                        effectStyleId: 0,
                        effectId: 0,
                        templateTitle: "Frame video",
                        requestUserId: purchaseManager.userId,
                        requestPrompt: prompt,
                        requestRatioRaw: "9:16",
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .frameVideo)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }
    
    private func completeStartGeneration(item: TemplateResult, generationType: GenerateType) {
        let resultId = item.id
        modelContext.insert(item)
        try? modelContext.save()
        mainViewModel.notifyHistoryUpdated()
        clearSentGenerateInput()
        
        if generationType == .animatePhoto {
            purchaseManager.spendGenerations(purchaseManager.generationPrice(for: generationType))
        } else {
            purchaseManager.spendGenerations(purchaseManager.generationVideoPrice(for: generationType))
        }
        
        isGenerating = false
        generationSession = GenerateSession(
            resultId: resultId,
            jobId: item.jobId,
            generationType: generationType
        )
    }
    
    private func clearSentGenerateInput() {
        mainViewModel.videoPromt = ""
        mainViewModel.leftVideoImage = nil
        mainViewModel.leftVideoItem = nil
        mainViewModel.rightVideoImage = nil
        mainViewModel.rightVideoItem = nil
    }
}

private struct VideoGenerationFlowView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var apiManager: APIManager
    
    enum Phase: Equatable {
        case creating
        case result(URL)
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
                    isVideo: true,
                    jobId: jobId,
                    onCompletePayload: { payload in
                        handleComplete(payload: payload)
                    },
                    onError: { error in
                        handleError(error)
                    }
                )
            case .result(let videoURL):
                GeneratedVideoView(videoURL: videoURL)
            }
        }
        .animation(.interpolatingSpring(duration: 0.35), value: phase)
    }
    
    private func handleComplete(payload: GenerationResultPayload) {
        do {
            guard payload.isVideo else {
                throw GenerationStatusError.apiError("Frame video returned non-video result")
            }
            
            let descriptor = FetchDescriptor<TemplateResult>(
                predicate: #Predicate { $0.id == resultId }
            )
            guard let item = try modelContext.fetch(descriptor).first else {
                throw GenerationStatusError.noData
            }
            
            let videoURL = try VideoStorageManager.saveVideo(data: payload.resultData, jobId: item.jobId)
            item.resultVideoLocalPath = videoURL.path
            item.isVideoResult = true
            item.generationTypeRaw = generationType.rawValue
            item.generationStatusRaw = TemplateResultStatus.completed.rawValue
            item.generationErrorMessage = nil
            if let previewData = payload.previewData {
                item.resultImageData = previewData
            } else if item.resultImageData == nil {
                item.resultImageData = item.inputPhotoData
            }
            
            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
            Task {
                await apiManager.authorize()
            }
            
            withAnimation(.interpolatingSpring(duration: 0.35)) {
                phase = .result(videoURL)
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
            VideoStorageManager.removeVideoIfExists(at: item.resultVideoLocalPath)
            item.resultVideoLocalPath = nil
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
