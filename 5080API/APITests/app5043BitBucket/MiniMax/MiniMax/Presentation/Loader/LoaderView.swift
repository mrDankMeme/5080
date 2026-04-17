
import SwiftUI

struct LoaderView: View {

    @StateObject private var vm = LoaderViewModel()
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color(hex:"#FFFFFF")!
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image("Loader.Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 114.scale, height: 114.scale)

                Spacer(minLength: 0)

                LoaderDotsView()
                    .padding(.bottom, 48.scale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            vm.start(duration: 1.5)
        }
        .onChange(of: vm.isFinished) { finished in
            guard finished else { return }
            onFinished()
        }
    }
}
