import PhotosUI
import SwiftUI

struct HomeActionsView: View {
    @ObservedObject var mainViewModel: MainViewModel
    
    var body: some View {
        HStack {
            if mainViewModel.photoPromt.count <= 300 {
                Text(String(mainViewModel.photoPromt.count) + "/300")
                    .font(.headline)
                    .foregroundStyle(Color.white)
            } else {
                VStack(alignment: .leading) {
                    Text(String(mainViewModel.photoPromt.count) + "/300")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#EC0D2A"))
                    
                    Text("Please remove extra text")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#EC0D2A"))
                }
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $mainViewModel.selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image("add.photo")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .padding(4)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                
                Button {
                    guard !mainViewModel.photoPromt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    UIPasteboard.general.string = mainViewModel.photoPromt
                    
                    mainViewModel.showSuccessBanner(text: "Text was copied")
                } label: {
                    Image("copy")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(10)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                
                Button {
                    mainViewModel.photoPromt.removeAll()
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
        .onChange(of: mainViewModel.selectedItem) {
            guard let item = mainViewModel.selectedItem else { return }

            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)
                {
                    mainViewModel.selectedImage = image
                }
            }
        }
    }
}
