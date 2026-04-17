import SwiftUI

enum RootTabItem: String, CaseIterable, Identifiable {
    case home
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var iconAssetName: String {
        switch self {
        case .home:
            return "E30_tab_home"
        case .history:
            return "E30_tab_history"
        case .settings:
            return "E30_tab_settings"
        }
    }
}

struct RootMainTabBar: View {
    @Binding var selectedTab: RootTabItem
    var onTapPlus: () -> Void = {}

    var body: some View {
        HStack(spacing: 12.scale) {
            HStack(spacing: 4.scale) {
                ForEach(RootTabItem.allCases) { tab in
                    RootTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            .padding(4.scale)
            .frame(width: 216.scale, height: 56.scale)
            .background(
                Capsule(style: .continuous)
                    .fill(Self.tabBarBackgroundColor)
            )

            Button(action: onTapPlus) {
                ZStack {
                    Circle()
                        .fill(Tokens.Color.accent)
                        .frame(width: 56.scale, height: 56.scale)

                    RootPlusButtonIcon()
                        .frame(width: 24.scale, height: 24.scale)
                }
                .frame(width: 64.scale, height: 64.scale)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create")
        }
        .frame(height: 64.scale)
        .padding(.horizontal, 16.scale)
        .padding(.top, 4.scale)
    }

    private static let tabBarBackgroundColor = Color(hex: "F5F5F5D9") ?? Color.white.opacity(0.85)
}

private struct RootTabButton: View {
    let tab: RootTabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6.scale) {
                Image(tab.iconAssetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24.scale, height: 24.scale)

                if isSelected {
                    Text(tab.title)
                        .font(Tokens.Font.medium14)
                        .kerning(-0.14.scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(isSelected ? Tokens.Color.accent : Self.inactiveColor)
            .frame(width: isSelected ? 104.scale : 48.scale, height: 48.scale)
            .background {
                if isSelected {
                    RootSelectedTabBackground()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private static let inactiveColor = Color(hex: "141414") ?? Color.black
}

private struct RootSelectedTabBackground: View {
    private static let centerTint = Color(hex: "F5F5F5D9") ?? Color.white.opacity(0.85)

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.98), location: 0.0),
                        .init(color: Self.centerTint, location: 0.5),
                        .init(color: Color.white.opacity(0.98), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(RootGlassEffectView())
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1.scale)
            )
    }
}

private struct RootGlassEffectView: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.72),
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.86),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.8.scale
                )
        )
    }
}

private struct RootPlusButtonIcon: View {
    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Tokens.Color.surfaceWhite)
                .frame(width: 13.5.scale, height: 2.2.scale)

            Capsule(style: .continuous)
                .fill(Tokens.Color.surfaceWhite)
                .frame(width: 2.2.scale, height: 13.5.scale)
        }
        .frame(width: 24.scale, height: 24.scale)
    }
}
