import SwiftUI
import SwiftData

struct HomeView: View {
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
        VStack(spacing: 8) {
            Text("You can add a photo, choose the aspect ratio or choose a style for the photo")
                .font(.callout)
                .foregroundStyle(Color(hex: "#B3B3B3").opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack {
                PromptView(text: $mainViewModel.photoPromt, placeholder: "Describe the image you want to create")
                    .focused($isPromptFocused)
                
                HStack(alignment: .bottom) {
                    ZStack(alignment: .topTrailing) {
                        if let image = mainViewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .frame(width: 78, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Button {
                                mainViewModel.selectedImage = nil
                                mainViewModel.selectedItem = nil
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
                    }
                    
                    Spacer()
                    
                    MainButton(title: "Generate", isLargeButton: false, cost: purchaseManager.generationPrice(for: mainViewModel.selectedImage == nil ? .textToImage : .imageToImage )) {
                        startGenerate()
                    }
                        .disabled(mainViewModel.photoPromt.isEmpty)
                        .opacity(mainViewModel.photoPromt.isEmpty ? 0.5 : 1)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            .padding(.horizontal)
            
            HomeActionsView(mainViewModel: mainViewModel)
                .padding(.horizontal)
            
            StylesView(mainViewModel: mainViewModel)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = false
        }
        .padding(.top)
        .fullScreenCover(item: $generationSession) { session in
            PhotoGenerationFlowView(
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
    
    private func startGenerate() {
        guard purchaseManager.isSubscribed else {
            showPaywall = true
            return
        }

        guard purchaseManager.availableGenerations >= purchaseManager.generationPrice(for: mainViewModel.selectedImage == nil ? .textToImage : .imageToImage ) else {
            showTokensPaywall = true
            return
        }
        
        if mainViewModel.selectedImage == nil {
            startTextToPhotoGeneration()
        } else {
            startEditPhotoGeneration()
        }
    }
    
    private func startTextToPhotoGeneration() {
        let prompt = mainViewModel.photoPromt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.textToPhoto(prompt: prompt, style: mainViewModel.selectedStyle)
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: nil,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.textToImage.rawValue,
                        isVideoResult: false,
                        resultVideoLocalPath: nil,
                        effectStyleId: mainViewModel.selectedStyle?.id ?? 0,
                        effectId: mainViewModel.selectedStyle?.preferredTemplateId ?? 0,
                        templateTitle: mainViewModel.selectedStyle?.title ?? GenerateType.textToImage.rawValue,
                        requestUserId: purchaseManager.userId,
                        requestPrompt: prompt,
                        requestStyleId: mainViewModel.selectedStyle?.id,
                        requestTemplateId: mainViewModel.selectedStyle?.preferredTemplateId,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .textToImage)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }

    private func startEditPhotoGeneration() {
        let prompt = mainViewModel.photoPromt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              let image = mainViewModel.selectedImage,
              let photoData = image.jpegData(compressionQuality: 0.9) else { return }

        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.editPhoto(prompt: prompt, style: mainViewModel.selectedStyle, photoData: photoData)
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: photoData,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.imageToImage.rawValue,
                        isVideoResult: false,
                        resultVideoLocalPath: nil,
                        effectStyleId: mainViewModel.selectedStyle?.id ?? 0,
                        effectId: mainViewModel.selectedStyle?.preferredTemplateId ?? 0,
                        templateTitle: mainViewModel.selectedStyle?.title ?? GenerateType.imageToImage.rawValue,
                        requestUserId: purchaseManager.userId,
                        requestPrompt: prompt,
                        requestStyleId: mainViewModel.selectedStyle?.id,
                        requestTemplateId: mainViewModel.selectedStyle?.preferredTemplateId,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .imageToImage)
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
        purchaseManager.spendGenerations(purchaseManager.generationPrice(for: generationType))
        
        isGenerating = false
        generationSession = GenerateSession(
            resultId: resultId,
            jobId: item.jobId,
            generationType: generationType
        )
    }
    
    private func clearSentGenerateInput() {
        mainViewModel.photoPromt = ""
        mainViewModel.selectedImage = nil
    }
}
