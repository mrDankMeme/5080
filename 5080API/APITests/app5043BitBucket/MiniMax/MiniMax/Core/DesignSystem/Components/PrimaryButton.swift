
import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public var isLoading: Bool
    public let action: () -> Void

    public var backgroundStyle: AnyShapeStyle
    public var foregroundStyle: AnyShapeStyle

    public init(
        title: String,
        isLoading: Bool = false,
        backgroundStyle: AnyShapeStyle = AnyShapeStyle(Tokens.Color.accent),
        foregroundStyle: AnyShapeStyle = AnyShapeStyle(Color.white),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.backgroundStyle = backgroundStyle
        self.foregroundStyle = foregroundStyle
        self.action = action
    }

    public var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundStyle)
                } else {
                    Text(title)
                        .font(Tokens.Font.medium17)
                }
            }
            .padding(.vertical, 14.scale)
            .frame(maxWidth: .infinity)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle)
            .cornerRadiusContinuous(Tokens.Radius.small)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
