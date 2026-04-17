import AVFoundation
import AVKit
import Photos
import SwiftUI

struct GeneratedVideoView: View {
    @Environment(\.dismiss) var dismiss
    
    let videoURL: URL
    var onClose: (() -> Void)? = nil
    
    @State private var showSuccessBanner = false
    @State private var showPermissionAlert: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var player: AVPlayer?
    @State private var videoSize: CGSize?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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
                    
                    Text("Ready!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        ZStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#252525").opacity(0.7))
                        .clipShape(Circle())
                        .padding(.trailing)
                    }
                }
                
                GeometryReader { geometry in
                    let availableSize = geometry.size
                    let fitSize = Self.fitSize(available: availableSize, videoSize: videoSize)
                    Group {
                        if let player {
                            VideoPlayer(player: player)
                        } else {
                            Color(hex: "#252525").opacity(0.7)
                        }
                    }
                    .frame(width: fitSize.width, height: fitSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                
                MainButton(title: "Save", isLargeButton: true, cost: nil) {
                    saveToGallery()
                }
                .padding(.horizontal)
            }
            
            if showSuccessBanner {
                VStack {
                    SuccessBanner(title: "Video was saved")
                    
                    Spacer()
                }
            }
        }
        .background(.primaryBackground)
        .alert("Access to Photo Library", isPresented: $showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow access to save videos in Settings.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [videoURL])
                .presentationDetents([.medium])
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            loadVideoSize()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private static func fitSize(available: CGSize, videoSize: CGSize?) -> CGSize {
        guard let videoSize, videoSize.width > 0, videoSize.height > 0 else {
            return available
        }
        let videoAspect = videoSize.width / videoSize.height
        let containerAspect = available.width / available.height
        if videoAspect >= containerAspect {
            let height = available.width / videoAspect
            return CGSize(width: available.width, height: height)
        } else {
            let width = available.height * videoAspect
            return CGSize(width: width, height: available.height)
        }
    }
    
    private func loadVideoSize() {
        Task {
            let asset = AVURLAsset(url: videoURL)
            guard let track = asset.tracks(withMediaType: .video).first else { return }
            let size = track.naturalSize.applying(track.preferredTransform)
            let result = CGSize(width: abs(size.width), height: abs(size.height))
            if result.width > 0, result.height > 0 {
                await MainActor.run {
                    videoSize = result
                }
            }
        }
    }
    
    private func saveToGallery() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    handlePhotoLibraryStatus(newStatus)
                }
            }
        default:
            handlePhotoLibraryStatus(status)
        }
    }
    
    private func handlePhotoLibraryStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited:
            performSave()
        case .denied, .restricted:
            showPermissionAlert = true
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    private func performSave() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        showSuccessBanner = true
                    }
                    
                    let workItem = DispatchWorkItem {
                        showSuccessBanner = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
                 }
            }
        }
    }
}

#Preview {
    let url = Bundle.main.url(forResource: "Ultraphotorealistic_wideangle_landscape_202", withExtension: "mp4")!
    return GeneratedVideoView(videoURL: url)
}
