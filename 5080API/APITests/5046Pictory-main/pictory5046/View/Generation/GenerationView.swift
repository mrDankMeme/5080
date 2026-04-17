import SwiftUI

struct GenerationView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var apiManager: APIManager
    @Environment(\.dismiss) private var dismiss
        
    @State private var rotation: Double = 0
    @State private var pollTask: Task<Void, Never>?
        
    var isVideo: Bool
    var jobId: String?
    var onComplete: ((UIImage) -> Void)?
    var onCompletePayload: ((GenerationResultPayload) -> Void)?
    var onError: ((Error) -> Void)?
    var onClose: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color(hex: "#252525")
                .opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .scaleEffect(1.4)
                        .padding()
                }
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 16).fill(
                    LinearGradient(
                        colors: [Color(hex: "#FD9958"), Color(hex: "#E149A0"), Color(hex: "#AB4BC3"), Color(hex: "#6851EA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                )
                
                VStack(spacing: 16) {
                    Text("Your \(isVideo ? "video" : "image") is generating")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("You may close this window \n and track progress in the History tab")
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }
                
                Button {
                    dismiss()
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color.white)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .padding(16)
                        .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let jobId {
                startPolling(jobId: jobId)
            }
        }
        .onDisappear {
            pollTask?.cancel()
        }
    }
        
    private func startPolling(jobId: String) {
        pollTask = Task {
            let userId = purchaseManager.userId
            while !Task.isCancelled {
                do {
                    let payload = try await apiManager.getGenerationStatusPayload(userId: userId, jobId: jobId)
                    guard !Task.isCancelled else { return }
                        
                    if payload.isVideo {
                        await MainActor.run {
                            if let onCompletePayload {
                                onCompletePayload(payload)
                            } else {
                                onError?(GenerationStatusError.apiError("Unexpected video result"))
                            }
                        }
                        return
                    }
                        
                    if let image = UIImage(data: payload.resultData) {
                        await MainActor.run {
                            onComplete?(image)
                        }
                        return
                    }
                        
                    await MainActor.run {
                        onError?(GenerationStatusError.invalidImageData)
                    }
                    return
                } catch let error as GenerationStatusError {
                    guard !Task.isCancelled else { return }
                    if case .notCompleted = error {
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }
                    await MainActor.run {
                        onError?(error)
                    }
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        onError?(error)
                    }
                    return
                }
            }
        }
    }
}

#Preview {
    GenerationView(isVideo: false)
        .environmentObject(APIManager.shared)
        .environmentObject(PurchaseManager.shared)
}
