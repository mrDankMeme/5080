import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.primaryBackground.ignoresSafeArea()

            VStack(spacing: 25) {
                Image("launch_icon")
                    .resizable()
                    .frame(width: 100, height: 100)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.white)
                    .scaleEffect(1.4)
                    .padding()
            }
        }
    }
}

#Preview {
    LaunchView()
}
