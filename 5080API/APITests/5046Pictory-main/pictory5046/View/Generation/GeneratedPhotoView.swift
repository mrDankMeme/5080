import Photos
import SwiftUI

struct GeneratedPhotoView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var img: UIImage
    
    @State private var showSuccessBanner = false
    @State private var showPermissionAlert: Bool = false
    @State private var showShareSheet: Bool = false
    
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
                
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                MainButton(title: "Save", isLargeButton: true, cost: nil) {
                    saveToGallery()
                }
                .padding(.horizontal)
            }
            
            if showSuccessBanner {
                VStack {
                    SuccessBanner(title: "Photo was saved")
                    
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
            ShareSheet(activityItems: [img])
                .presentationDetents([.medium])
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
            PHAssetChangeRequest.creationRequestForAsset(from: img)
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
    GeneratedPhotoView(img: UIImage(resource: .rateus))
}
