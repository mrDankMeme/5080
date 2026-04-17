import SwiftUI

public struct OnboardingButton: View {
    public let title: String
    public var isLoading: Bool
    public let action: () -> Void

    public init(
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    private var gradient: LinearGradient {
        let baseStart = UnitPoint(x: 0.4, y: 0.0)
        let baseEnd   = UnitPoint(x: 1.0, y: 0.5)
        let rotatedStart = baseStart.rotated(angleDegrees: 49)
        let rotatedEnd   = baseEnd.rotated(angleDegrees: 49)

        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "#396DF4")!, location: 0.0),
                .init(color: Color(hex: "#374BF0")!, location: 1.0)
            ])
,
            startPoint: rotatedStart,
            endPoint: rotatedEnd
        )
    }

    public var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(Tokens.Color.textSecondary)
                        .progressViewStyle(.circular)
                } else {
                    Text(title)
                        .font(Tokens.Font.semibold16)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16.scale)
            .background(Tokens.Color.accentGradient)
            .cornerRadiusContinuous(16.scale)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private extension UnitPoint {
    func rotated(
        around center: UnitPoint = .center,
        angleDegrees: Double
    ) -> UnitPoint {
        let angle = angleDegrees * .pi / 180

        let dx = x - center.x
        let dy = y - center.y

        let nx = dx * Foundation.cos(angle) - dy * Foundation.sin(angle)
        let ny = dx * Foundation.sin(angle) + dy * Foundation.cos(angle)

        return UnitPoint(x: center.x + nx, y: center.y + ny)
    }
}
