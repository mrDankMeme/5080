import PhotosUI
import SwiftData
import SwiftUI

struct EnhancerView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchaseManager: PurchaseManager
    
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var generationSession: GenerateSession?
    @State private var showPaywall: Bool = false
    @State private var showTokensPaywall: Bool = false
    
    private var enhanceGenerationPrice: Int {
        purchaseManager.enhanceGenerationPrice
    }

    var body: some View {
        VStack {
            PhotosPicker(
                selection: $mainViewModel.selectedEnhanceItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                if let image = mainViewModel.selectedEnhanceImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else {
                    VStack(alignment: .center, spacing: 20) {
                        Image("uploading-photos")
                            .background(Color(hex: "#252525").opacity(0.82))
                            .clipShape(Circle())

                        VStack {
                            Text("Add Photo")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Text("Tap to enhance your image")
                                .font(.body)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if mainViewModel.selectedEnhanceImage == nil {
                PhotosPicker(
                    selection: $mainViewModel.selectedEnhanceItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 4) {
                        Text("Add a photo")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 40).fill(
                        LinearGradient(
                            colors: [Color(hex: "#FD9958"), Color(hex: "#E149A0"), Color(hex: "#AB4BC3"), Color(hex: "#6851EA")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 40).stroke(LinearGradient(
                            colors: [Color.white.opacity(0), Color.white, Color.white.opacity(0)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            } else {
                MainButton(title: "Enhance", isLargeButton: true, cost: enhanceGenerationPrice) {
                    startGeneration()
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .onChange(of: mainViewModel.selectedEnhanceItem) {
            guard let item = mainViewModel.selectedEnhanceItem else { return }

            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)
                {
                    mainViewModel.selectedEnhanceImage = image
                }
            }
        }
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
    
    private func startGeneration() {
        guard let image = mainViewModel.selectedEnhanceImage,
                let photoData = image.jpegData(compressionQuality: 0.9) else { return }
        
        guard purchaseManager.isSubscribed else {
            showPaywall = true
            return
        }
        guard purchaseManager.availableGenerations >= enhanceGenerationPrice  else {
            showTokensPaywall = true
            return
        }

        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.enhancePhoto(photoData: photoData)
                await MainActor.run {
                    let item = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: photoData,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.enhancePhoto.rawValue,
                        effectStyleId: 0,
                        effectId: 0,
                        templateTitle: "Enhance Photo",
                        requestUserId: purchaseManager.userId,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    completeStartGeneration(item: item, generationType: .enhancePhoto)
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
        purchaseManager.spendGenerations(enhanceGenerationPrice)
        
        isGenerating = false
        generationSession = GenerateSession(
            resultId: resultId,
            jobId: item.jobId,
            generationType: generationType
        )
    }
    
    private func clearSentGenerateInput() {
        mainViewModel.selectedEnhanceItem = nil
        mainViewModel.selectedEnhanceImage = nil
    }
}
