import SwiftUI

struct VideoGenerationOptionsView: View {
    @ObservedObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 22) {
            ForEach(VideoGenerationOption.allCases) { option in
                Button {
                    mainViewModel.selectedVideoGenerationOption = option
                    mainViewModel.showVideoGenerationOptionsView = false
                } label: {
                    Text(option.description)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(hex: "#252525"))
                        )
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
}
