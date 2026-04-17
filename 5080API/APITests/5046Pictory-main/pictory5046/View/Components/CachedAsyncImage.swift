import SwiftUI

struct CachedAsyncImage: View {
    let urlString: String?
    var contentMode: ContentMode = .fill
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .allowsHitTesting(false)
            } else {
                Color.white.opacity(0.08)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .tint(Color.white)
                        }
                    }
            }
        }
        .task(id: urlString) {
            await MainActor.run { image = nil }
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let urlString, !urlString.isEmpty else { return }
        
        await MainActor.run { isLoading = true }
        
        let loaded = await ImageCacheManager.shared.image(for: urlString)
        
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            image = loaded
            isLoading = false
        }
    }
}
