import SwiftUI

struct AspectRatioView: View {
    @ObservedObject var mainViewModel: MainViewModel

    @Binding var selectedAspectRatio: AspectRatio

    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AspectRatio.allCases) { item in
                    ratioButton(item: item)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func ratioButton(item: AspectRatio) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedAspectRatio = item
                mainViewModel.isAspectRatioViewVisible = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)

                Text(item.description)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(
                    item.description == selectedAspectRatio.description
                        ? Color.white
                        : Color.clear, lineWidth: 1
                )
            )
        }
    }
}
