import PhotosUI
import SwiftUI

struct VideoActionsView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    var body: some View {
        HStack {
            if mainViewModel.videoPromt.count <= 300 {
                Text(String(mainViewModel.videoPromt.count) + "/300")
                    .font(.headline)
                    .foregroundStyle(Color.white)
            } else {
                VStack(alignment: .leading) {
                    Text(String(mainViewModel.videoPromt.count) + "/300")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#EC0D2A"))
                    
                    Text("Please remove extra text")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#EC0D2A"))
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button {
                    guard !mainViewModel.videoPromt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    UIPasteboard.general.string = mainViewModel.videoPromt
                    
                    mainViewModel.showSuccessBanner(text: "Text was copied")
                } label: {
                    Image("copy")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(10)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                
                Button {
                    mainViewModel.videoPromt.removeAll()
                    
                    mainViewModel.selectedVideoImage = nil
                    mainViewModel.selectedVideoItem = nil
                    
                    mainViewModel.leftVideoItem = nil
                    mainViewModel.leftVideoImage = nil
                    mainViewModel.rightVideoItem = nil
                    mainViewModel.rightVideoImage = nil
                } label: {
                    Image("trash")
                        .resizable()
                        .foregroundStyle(Color(hex: "#FBACB7"))
                        .frame(width: 20, height: 20)
                        .padding(10)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
            }
        }
    }
}

