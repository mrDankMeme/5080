import Photos
import PhotosUI
import SwiftData
import SwiftUI

struct SelectedTemplateView: View {
    @ObservedObject var mainViewModel: MainViewModel

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.openURL) private var openURL
    var effectWithTemplate: EffectWithTemplate

    @State private var img: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoAccessDeniedAlert = false
    @State private var flowPhase: FlowPhase = .picking
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var showSubscriptionPaywall = false
    @State private var showPaywall: Bool = false
    @State private var showTokensPaywall: Bool = false

    var wCard: CGFloat { UIScreen.main.bounds.width - 32 }
    var hCard: CGFloat { wCard * 1.2653631285 }

    private var previewURL: String? {
        effectWithTemplate.effect.preview ?? effectWithTemplate.template.preview
    }

    private var templateGenerationPrice: Int {
        purchaseManager.templateGenerationPrice
    }

    var body: some View {
        ZStack {
            switch flowPhase {
            case .picking:
                pickingContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
            case .creating(let resultId, let jobId):
                GenerationView(
                    isVideo: false,
                    jobId: jobId,
                    onComplete: { image in
                        if let data = image.jpegData(compressionQuality: 0.9) {
                            updateTemplateResult(resultId: resultId, resultData: data)
                        }
                        Task {
                            await apiManager.authorize()
                        }
                        withAnimation(.interpolatingSpring(duration: 0.35)) {
                            flowPhase = .result(image)
                        }
                    },
                    onError: { error in
                        markTemplateResultFailed(resultId: resultId, message: error.localizedDescription)
                        Task {
                            await apiManager.authorize()
                        }
                        generationError = error.localizedDescription
                        withAnimation(.interpolatingSpring(duration: 0.35)) {
                            flowPhase = .picking
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity.combined(with: .scale(scale: 1.02))
                ))
            case .result(let resultImage):
                GeneratedPhotoView(img: resultImage)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
            }
        }
        .animation(.interpolatingSpring(duration: 0.35), value: flowPhase)
        .background(Color.primaryBackground)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            loadSelectedPhoto(item)
        }
        .alert("Error", isPresented: .init(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )) {
            Button("OK") { generationError = nil }
        } message: {
            if let error = generationError {
                Text(error)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showTokensPaywall) {
            TokensPaywallView()
        }
        .navigationBarBackButtonHidden()
    }

    private var pickingContent: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .contentShape(Rectangle())
                        .padding(.leading)
                }

                Spacer()

                Text("Templates")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    if !purchaseManager.isSubscribed {
                        showPaywall = true
                    } else {
                        showTokensPaywall = true
                    }
                } label: {
                    HStack {
                        if !purchaseManager.isSubscribed {
                            Text("PRO")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Image("sparkles")
                                .frame(height: 32)
                        } else {
                            Image("rhombus.fill")
                                .frame(height: 32)
                            
                            Text("\(purchaseManager.availableGenerations)")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 40).fill(
                        LinearGradient(colors: [Color(hex: "#D447AB"), Color(hex: "#7650E3")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .padding(.trailing)
                }
            }

            VStack(spacing: 16) {
                CachedAsyncImage(urlString: previewURL, contentMode: .fill)
                    .frame(width: wCard, height: hCard)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                imgPicker
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: 100)
            }
            .padding(.horizontal)

            MainButton(title: "Generate", isLargeButton: true, cost: templateGenerationPrice) {
                startGeneration()
            }
            .disabled(img == nil || isGenerating)
            .padding(.horizontal)
        }
        .padding(.bottom)
    }

    private func startGeneration() {
        guard let img, let photoData = img.jpegData(compressionQuality: 0.9) else { return }
        guard purchaseManager.isSubscribed else {
            showSubscriptionPaywall = true
            return
        }
        guard purchaseManager.availableGenerations >= templateGenerationPrice else {
            showTokensPaywall = true
            return
        }

        isGenerating = true
        Task {
            do {
                let jobId = try await apiManager.generateEffect(effectWithTemplate: effectWithTemplate, photoData: photoData)
                await MainActor.run {
                    let result = TemplateResult(
                        jobId: jobId,
                        inputPhotoData: photoData,
                        resultImageData: nil,
                        generationTypeRaw: GenerateType.template.rawValue,
                        effectStyleId: effectWithTemplate.template.id,
                        effectId: effectWithTemplate.effect.id,
                        templateTitle: effectWithTemplate.effect.title,
                        requestUserId: purchaseManager.userId,
                        requestTemplateId: effectWithTemplate.effect.id,
                        generationStatusRaw: TemplateResultStatus.pending.rawValue
                    )
                    let resultId = result.id
                    modelContext.insert(result)
                    try? modelContext.save()
                    mainViewModel.notifyHistoryUpdated()
                    purchaseManager.spendGenerations(templateGenerationPrice)
                    isGenerating = false
                    withAnimation(.interpolatingSpring(duration: 0.35)) {
                        flowPhase = .creating(resultId: resultId, jobId: jobId)
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationError = error.localizedDescription
                }
            }
        }
    }

    private func updateTemplateResult(resultId: UUID, resultData: Data) {
        let descriptor = FetchDescriptor<TemplateResult>(
            predicate: #Predicate { $0.id == resultId }
        )
        if let item = try? modelContext.fetch(descriptor).first {
            item.resultImageData = resultData
            item.generationStatusRaw = TemplateResultStatus.completed.rawValue
            item.generationErrorMessage = nil
            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
        }
    }

    private func markTemplateResultFailed(resultId: UUID, message: String) {
        let descriptor = FetchDescriptor<TemplateResult>(
            predicate: #Predicate { $0.id == resultId }
        )
        if let item = try? modelContext.fetch(descriptor).first {
            item.generationStatusRaw = TemplateResultStatus.failed.rawValue
            item.generationErrorMessage = message
            try? modelContext.save()
            mainViewModel.notifyHistoryUpdated()
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let newImage = UIImage(data: data)
            {
                await MainActor.run {
                    img = newImage
                    selectedPhotoItem = nil
                }
            } else {
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
    }

    var imgPicker: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                if let img = img {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                                .blur(radius: 25)
                        )
                        .allowsHitTesting(false)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image("add.photo")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#252525").opacity(0.82))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(img != nil)
        .overlay(alignment: .topTrailing) {
            if img != nil {
                Button {
                    img = nil
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
        .animation(.interpolatingSpring(duration: 0.2), value: img)
    }
}
