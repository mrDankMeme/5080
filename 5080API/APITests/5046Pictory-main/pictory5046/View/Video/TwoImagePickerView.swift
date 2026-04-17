import PhotosUI
import SwiftUI

struct TwoImagePickerView: View {
    @ObservedObject var mainViewModel: MainViewModel

    var body: some View {
        HStack(spacing: 8) {
            imagePicker(
                image: $mainViewModel.leftVideoImage,
                item: $mainViewModel.leftVideoItem
            )

            swapButton

            imagePicker(
                image: $mainViewModel.rightVideoImage,
                item: $mainViewModel.rightVideoItem
            )
        }
        .padding(.top, 32)
    }

    func imagePicker(image: Binding<UIImage?>, item: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            if let uiImage = image.wrappedValue {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        image.wrappedValue = nil
                        item.wrappedValue = nil
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
            } else {
                ZStack {
                    Image("add.photo")
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#252525").opacity(0.82)))
            }
        }
        .onChange(of: item.wrappedValue) {
            guard let item = item.wrappedValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data)
                {
                    image.wrappedValue = uiImage
                }
            }
        }
    }

    var swapButton: some View {
        Button {
            let image = mainViewModel.leftVideoImage
            mainViewModel.leftVideoImage = mainViewModel.rightVideoImage
            mainViewModel.rightVideoImage = image
        } label: {
            Image("change")
        }
    }
}
