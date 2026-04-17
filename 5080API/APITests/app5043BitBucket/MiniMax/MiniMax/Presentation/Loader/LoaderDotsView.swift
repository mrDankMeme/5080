import SwiftUI

struct LoaderDotsView: View {

    // MARK: - Layout

    private let dotSize: CGFloat = 12.scale
    private let spacing: CGFloat = 11.scale

    // MARK: - State

    @State private var activeIndex: Int = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        HStack(spacing: spacing) {
            dot(isActive: activeIndex == 0)
            dot(isActive: activeIndex == 1)
            dot(isActive: activeIndex == 2)
        }
        .onAppear { startLoop() }
        .onDisappear { stopLoop() }
        .accessibilityLabel("Loading")
    }

    private func dot(isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Color(hex: "#6A4FF1")! : Color(hex: "#6A4FF1")!.opacity(0.3))
            .frame(width: dotSize, height: dotSize)
    }

    private func startLoop() {
        stopLoop()

        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000)

            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.28)) {
                    activeIndex = (activeIndex + 1) % 3
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
        }
    }

    private func stopLoop() {
        task?.cancel()
        task = nil
    }
}
