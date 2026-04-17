import SwiftData
import SwiftUI

private struct HistoryResultSelection: Identifiable {
    let id: UUID
    let result: TemplateResult
}

struct HistoryView: View {
    @ObservedObject var mainViewModel: MainViewModel

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Query(sort: [SortDescriptor(\TemplateResult.createdAt, order: .reverse)]) private var templateResults: [TemplateResult]

    @State private var tabBarWidth: CGFloat = 0
    @State private var selectedTemplateResult: HistoryResultSelection?
    @State private var retryingResultIds: Set<UUID> = []
    @State private var historyError: String?
    @State private var showSubscriptionPaywall = false
    @State private var showTokensPaywall = false
    @Namespace private var namespace

    private var filteredResults: [TemplateResult] {
        switch mainViewModel.historyGenType {
        case .enhancer:
            return templateResults.filter { result in
                let type = result.generationTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
                return type == "Enhance Photo"
            }
        case .generation:
            return templateResults.filter { result in
                let type = result.generationTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
                return type != "Template" && type != "Enhance Photo"
            }
        case .template:
            return templateResults.filter { result in
                let type = result.generationTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
                return type == "Template"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            generateTypePicker

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 2), alignment: .leading, spacing: 8) {
                    ForEach(filteredResults, id: \.id) { result in
                        HistoryCard(
                            result: result,
                            onTap: {
                                selectedTemplateResult = HistoryResultSelection(id: result.id, result: result)
                            },
                            onRetry: {
                                handleRetry(result)
                            },
                            onDelete: {
                                deleteResult(result)
                            },
                            isRetrying: retryingResultIds.contains(result.id)
                        )
                        .id(result.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top)
        .task(id: mainViewModel.historyRefreshTrigger) {
            await mainViewModel.retryIncompleteTemplateResults(
                apiManager: apiManager,
                container: DataManager.container
            )
        }
        .fullScreenCover(item: $selectedTemplateResult) { selection in
            GeneratedView(result: selection.result, mainViewModel: mainViewModel)
        }
        .alert("Error", isPresented: .init(
            get: { historyError != nil },
            set: { if !$0 { historyError = nil } }
        )) {
            Button("OK") { historyError = nil }
        } message: {
            if let historyError {
                Text(historyError)
            }
        }
//        .fullScreenCover(isPresented: $showSubscriptionPaywall) {
//            PaywallView()
//        }
//        .fullScreenCover(isPresented: $showTokensPaywall) {
//            PaywallTokensView()
//        }
    }

    private var generateTypePicker: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(HistoryGenType.allCases) { type in
                var isSelected: Bool { mainViewModel.historyGenType == type }

                Button {
                    mainViewModel.historyGenType = type
                } label: {
                    Text(type.rawValue)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : Color(hex: "#B3B3B3").opacity(0.82))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color(hex: "#252525").opacity(0.7) : Color(hex: "#323131"))
                        )
                        .overlay(content: {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#FD9958"),
                                                Color(hex: "#E149A0"),
                                                Color(hex: "#AB4BC3"),
                                                Color(hex: "#6851EA")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                    .shadow(
                                        color: Color(hex: "#FFB1EF").opacity(0.35),
                                        radius: 17.8
                                    )
                            }
                        })
                        .animation(.interpolatingSpring(duration: 0.2), value: isSelected)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func retryCost(for result: TemplateResult) -> Int {
        let typeRaw = result.generationTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let typeRaw, !typeRaw.isEmpty, let generateType = GenerateType(rawValue: typeRaw) {
            return purchaseManager.generationPrice(for: generateType)
        }
        return purchaseManager.templateGenerationPrice
    }

    private func deleteResult(_ result: TemplateResult) {
        guard !retryingResultIds.contains(result.id) else { return }
        VideoStorageManager.removeVideoIfExists(at: result.resultVideoLocalPath)
        modelContext.delete(result)
        try? modelContext.save()
        mainViewModel.notifyHistoryUpdated()
    }

    private func handleRetry(_ result: TemplateResult) {
        guard result.isFailed else { return }
        guard !retryingResultIds.contains(result.id) else { return }

//        guard purchaseManager.isSubscribed else {
//            showSubscriptionPaywall = true
//            return
//        }
//
        let cost = retryCost(for: result)
//        guard purchaseManager.availableGenerations >= cost else {
//            showTokensPaywall = true
//            return
//        }

        Task {
            await retryFailedResult(resultId: result.id, cost: cost)
        }
    }

    @MainActor
    private func retryFailedResult(resultId: UUID, cost: Int) async {
        guard let item = fetchResult(by: resultId) else { return }
        retryingResultIds.insert(resultId)
        defer { retryingResultIds.remove(resultId) }

        do {
            let newJobId = try await startRetryGeneration(for: item)

            item.jobId = newJobId
            item.resultImageData = nil
            item.resultVideoLocalPath = nil
            item.generationStatusRaw = TemplateResultStatus.pending.rawValue
            item.generationErrorMessage = nil
            item.createdAt = Date()
            try? modelContext.save()
            purchaseManager.spendGenerations(cost)
            mainViewModel.notifyHistoryUpdated()

            try await pollRetriedGeneration(resultId: resultId, jobId: newJobId)
            await apiManager.authorize()
        } catch {
            if let failedItem = fetchResult(by: resultId) {
                failedItem.generationStatusRaw = TemplateResultStatus.failed.rawValue
                failedItem.generationErrorMessage = error.localizedDescription
                try? modelContext.save()
                mainViewModel.notifyHistoryUpdated()
            }
            await apiManager.authorize()
            historyError = error.localizedDescription
        }
    }

    @MainActor
    private func startRetryGeneration(for item: TemplateResult) async throws -> String {
        let typeRaw = item.generationTypeRaw?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let typeRaw, let generationType = GenerateType(rawValue: typeRaw) else {
            throw GenerationStatusError.apiError("Unknown generation type for retry")
        }

        switch generationType {
        case .textToImage:
            let prompt = item.requestPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                throw GenerationStatusError.apiError("Missing prompt for retry")
            }
            let templateId = item.requestTemplateId ?? item.effectId
            return try await apiManager.textToPhoto(
                prompt: prompt,
                templateId: templateId,
                styleId: item.requestStyleId ?? item.effectStyleId
            )

        case .imageToImage:
            let prompt = item.requestPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                throw GenerationStatusError.apiError("Missing prompt for retry")
            }
            guard let photoData = item.inputPhotoData else {
                throw GenerationStatusError.apiError("Missing source photo for retry")
            }
            let templateId = item.requestTemplateId ?? item.effectId
            return try await apiManager.editPhoto(
                prompt: prompt,
                templateId: templateId,
                styleId: item.requestStyleId ?? item.effectStyleId,
                photoData: photoData
            )

        case .textToVideo:
            let prompt = item.requestPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                throw GenerationStatusError.apiError("Missing prompt for retry")
            }

            return try await apiManager.generateVideo(
                prompt: prompt
            )

        case .animatePhoto:
            let prompt = item.requestPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                throw GenerationStatusError.apiError("Missing prompt for retry")
            }
            guard let startFrameData = item.inputPhotoData
            else {
                throw GenerationStatusError.apiError("Missing photos for retry")
            }
            return try await apiManager.animatePhoto(
                prompt: prompt,
                frameData: startFrameData
            )

        case .frameVideo:
            let prompt = item.requestPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !prompt.isEmpty else {
                throw GenerationStatusError.apiError("Missing prompt for retry")
            }
            guard let startFrameData = item.inputPhotoData,
                  let endFrameData = item.inputPhotoSecondData
            else {
                throw GenerationStatusError.apiError("Missing photos for retry")
            }

            return try await apiManager.generateFrameVideo(
                prompt: prompt,
                startFrameData: startFrameData,
                endFrameData: endFrameData
            )
            
        case .enhancePhoto:
            guard let frameData = item.inputPhotoData
            else {
                throw GenerationStatusError.apiError("Missing photos for retry")
            }
            return try await apiManager.enhancePhoto(
                photoData: frameData
            )
            
        case .template:
            guard let photoData = item.inputPhotoData else {
                throw GenerationStatusError.apiError("Missing source photo for retry")
            }
            let templateId = item.requestTemplateId ?? item.effectId
            return try await apiManager.generateEffect(templateId: templateId, photoData: photoData)
        }
    }

    @MainActor
    private func pollRetriedGeneration(resultId: UUID, jobId: String) async throws {
        while true {
            do {
                let payload = try await apiManager.getGenerationStatusPayload(
                    userId: purchaseManager.userId,
                    jobId: jobId
                )

                guard let item = fetchResult(by: resultId) else {
                    throw GenerationStatusError.noData
                }

                if payload.isVideo {
                    let url = try VideoStorageManager.saveVideo(data: payload.resultData, jobId: jobId)
                    item.resultVideoLocalPath = url.path
                    item.isVideoResult = true
                    if let previewData = payload.previewData {
                        item.resultImageData = previewData
                    } else if item.resultImageData == nil {
                        item.resultImageData = item.inputPhotoData
                    }
                } else {
                    item.resultImageData = payload.resultData
                    item.isVideoResult = false
                    item.resultVideoLocalPath = nil
                }

                item.generationStatusRaw = TemplateResultStatus.completed.rawValue
                item.generationErrorMessage = nil
                try? modelContext.save()
                mainViewModel.notifyHistoryUpdated()
                return
            } catch let error as GenerationStatusError {
                if case .notCompleted = error {
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                throw error
            }
        }
    }

    @MainActor
    private func fetchResult(by id: UUID) -> TemplateResult? {
        let descriptor = FetchDescriptor<TemplateResult>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
