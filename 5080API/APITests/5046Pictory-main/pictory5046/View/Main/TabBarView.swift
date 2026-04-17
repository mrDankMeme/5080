import SwiftUI

struct TabBarView: View {
    @ObservedObject var mainViewModel: MainViewModel

    var body: some View {
        HStack {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        mainViewModel.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 0) {
                        Image(tab.icon)
                            .frame(width: 32, height: 32)
                            .foregroundColor(mainViewModel.selectedTab == tab ? Color.white : Color.white.opacity(0.4))

                        Text(tab.title)
                            .font(mainViewModel.selectedTab == tab ? .caption2.weight(.semibold) : .caption2)
                            .foregroundColor(mainViewModel.selectedTab == tab ? Color.white : Color.white.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 34)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 16,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 16
            )).fill(.primaryBackground)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: 16,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: 16
            )).stroke(Color.white.opacity(0.24), lineWidth: 0.33)
        )
    }
}
