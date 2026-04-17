import SwiftUI

struct HistoryCard: View {
    var result: TemplateResult
    var onTap: (() -> Void)?
    var onRetry: (() -> Void)?
    var onDelete: (() -> Void)?
    var isRetrying: Bool = false
    
    @State private var isImageLoaded = false
    
    var wCard: CGFloat { (UIScreen.main.bounds.width - 56) / 2 }
    var hCard: CGFloat { wCard * 1.2114285714 }
    
    var body: some View {
        let isCompleted = result.isCompleted
        let isFailed = result.isFailed
        let showLoading = result.isPending || (result.resultImage != nil && !isImageLoaded)
        
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                ZStack(alignment: .topTrailing) {
                    if let resultImage = result.resultImage {
                        Image(uiImage: resultImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                            .frame(width: wCard, height: hCard)
                            .clipped()
                            .opacity(isImageLoaded ? 1 : 0)
                            .onAppear { isImageLoaded = true }
                            .id(result.id.uuidString + (result.isCompleted ? "-done" : "-pending"))
                    } else {
                        Image("history_card")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: wCard, height: hCard)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .clipped()
                    }
                    
                    if !showLoading {
                        Button {
                            onDelete?()
                        } label: {
                            Image("trash")
                                .foregroundColor(Color(hex: "#FFB2BC"))
                                .padding(4)
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "#252525").opacity(0.9))
                                .clipShape(Circle())
                                .padding(.trailing, 4)
                                .padding(.top, 4)
                        }
                        .disabled(isRetrying)
                    }
                }
                
                if showLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.white)
                        .scaleEffect(1.3)
                        .allowsHitTesting(false)
                        .frame(width: 44, height: 44)
                }

                if isFailed {
                    VStack(spacing: 8) {
                        Text("Something \n went wrong")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 8) {
                            Button {
                                onRetry?()
                            } label: {
                                if isRetrying {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color.black)
                                        .scaleEffect(0.7)
                                        .frame(height: 28)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Try again")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 100)
                                                .fill(Color(hex: "#252525").opacity(0.82))
                                        )
                                }
                            }
                            .disabled(isRetrying)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text(result.requestPrompt ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#252525").opacity(0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            guard isCompleted else { return }
            onTap?()
        }
    }
}
