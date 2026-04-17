

import SwiftUI

private struct EdgeSwipeCapture: View {
    let isEnabled: Bool
    let edgeWidth: CGFloat
    let triggerDistance: CGFloat
    let onPop: () -> Void

    @State private var started = false
    @State private var startLocation: CGPoint = .zero

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: edgeWidth)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !started {
                            started = true
                            startLocation = value.startLocation
                        }
                    }
                    .onEnded { value in
                        defer { started = false }
                        guard isEnabled else { return }

                        let validStart = startLocation.x <= edgeWidth + 2
                        let dx = value.translation.width
                        let dy = value.translation.height

                        if validStart && dx > triggerDistance && abs(dy) < 120 {
                            onPop()
                        }
                    }
            )
            .allowsHitTesting(isEnabled)
    }
}

private struct EdgeSwipeBackModifier: ViewModifier {
    let isEnabled: Bool
    let edgeWidth: CGFloat
    let triggerDistance: CGFloat
    let onPop: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(
                EdgeSwipeCapture(
                    isEnabled: isEnabled,
                    edgeWidth: edgeWidth,
                    triggerDistance: triggerDistance,
                    onPop: onPop
                ),
                alignment: .leading
            )
    }
}

public extension View {
    func edgeSwipeToPop(
        isEnabled: Bool,
        edgeWidth: CGFloat = 24,
        triggerDistance: CGFloat = 60,
        onPop: @escaping () -> Void
    ) -> some View {
        modifier(
            EdgeSwipeBackModifier(
                isEnabled: isEnabled,
                edgeWidth: edgeWidth,
                triggerDistance: triggerDistance,
                onPop: onPop
            )
        )
    }
}
