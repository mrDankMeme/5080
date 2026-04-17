import Combine
import PhotosUI
import SwiftUI
import SwiftData

final class MainViewModel: ObservableObject {
    @Published var selectedTab: Tab = .home
    
    @Published var photoPromt = ""
    @Published var videoPromt = ""
    
    @Published var selectedAspectRatio: AspectRatio = .aspectRatio1x1
    @Published var isAspectRatioViewVisible = false
    
    @Published var showSuccessBanner = false
    @Published var successBannerText = ""
    
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var selectedImage: UIImage? = nil
    
    @Published var selectedStyle: PhotoStyleItem? = nil
    
    @Published var selectedEffect: EffectWithTemplate?
    
    @Published var selectedEnhanceItem: PhotosPickerItem? = nil
    @Published var selectedEnhanceImage: UIImage? = nil
    
    @Published var selectedVideoGenerationOption: VideoGenerationOption = .promptToVideo
    @Published var showVideoGenerationOptionsView = false
    
    @Published var selectedVideoItem: PhotosPickerItem? = nil
    @Published var selectedVideoImage: UIImage? = nil
    
    @Published var leftVideoImage: UIImage? = nil
    @Published var rightVideoImage: UIImage? = nil

    @Published var leftVideoItem: PhotosPickerItem? = nil
    @Published var rightVideoItem: PhotosPickerItem? = nil
    
    @Published var historyGenType: HistoryGenType = .enhancer
    @Published var historyRefreshTrigger = UUID()
    
    @Published var appStoreVersion: String? = nil
    var appVersion: String {
        if let storeVersion = appStoreVersion, !storeVersion.isEmpty {
            return storeVersion
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }
    
    var isGenerateDisabled: Bool {
        switch selectedVideoGenerationOption {
        case .promptToVideo:
            return videoPromt.isEmpty
            
        case .photoToAnimation:
            return videoPromt.isEmpty || selectedVideoImage == nil
            
        case .photosToStoryVideo:
            return videoPromt.isEmpty || leftVideoImage == nil || rightVideoImage == nil
        }
    }
    
    func showSuccessBanner(text: String) {
        successBannerText = text
        
        withAnimation {
            showSuccessBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showSuccessBanner = false
            }
        }
    }
    
    /// Notifies History that it should refresh the list (after generation finishes).
    func notifyHistoryUpdated() {
        historyRefreshTrigger = UUID()
    }
    
    /// Re-checks results for unfinished generations when the app is reopened.
    func retryIncompleteTemplateResults(apiManager: APIManager, container: ModelContainer) async {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TemplateResult>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            let all = try context.fetch(descriptor)
            let incomplete = all.filter { $0.isPending }
            let userId = await MainActor.run { PurchaseManager.shared.userId }
            var didUpdate = false
            for item in incomplete {
                do {
                    let payload = try await apiManager.getGenerationStatusPayload(userId: userId, jobId: item.jobId)
                    if payload.isVideo {
                        let url = try VideoStorageManager.saveVideo(data: payload.resultData, jobId: item.jobId)
                        item.resultVideoLocalPath = url.path
                        item.isVideoResult = true
                        if let preview = payload.previewData {
                            item.resultImageData = preview
                        } else if item.resultImageData == nil {
                            item.resultImageData = item.inputPhotoData
                        }
                    } else {
                        item.resultImageData = payload.resultData
                        item.isVideoResult = false
                    }
                    item.generationStatusRaw = TemplateResultStatus.completed.rawValue
                    item.generationErrorMessage = nil
                    try context.save()
                    didUpdate = true
                } catch let error as GenerationStatusError {
                    if case .notCompleted = error {
                        continue
                    }
                    item.generationStatusRaw = TemplateResultStatus.failed.rawValue
                    item.generationErrorMessage = error.localizedDescription
                    try? context.save()
                    didUpdate = true
                } catch {
                    item.generationStatusRaw = TemplateResultStatus.failed.rawValue
                    item.generationErrorMessage = error.localizedDescription
                    try? context.save()
                    didUpdate = true
                }
            }
            if didUpdate {
                await MainActor.run { notifyHistoryUpdated() }
            }
        } catch {}
    }
}
