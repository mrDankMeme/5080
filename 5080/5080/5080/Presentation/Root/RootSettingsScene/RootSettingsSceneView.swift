import SwiftUI
import Swinject

struct RootSettingsSceneView: View {
    @Environment(\.resolver) private var resolver
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject var viewModel: RootSettingsSceneViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24.scale) {
                ForEach(viewModel.sections) { section in
                    sectionView(section)
                }

                Text(viewModel.applicationVersionText)
                    .font(Tokens.Font.regular13)
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .kerning(-0.13.scale)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16.scale)
            .padding(.top, 16.scale)
            .padding(.bottom, 120.scale)
        }
        .safeAreaInset(edge: .top, spacing: 0.scale) {
            headerView
                .padding(.horizontal, 16.scale)
                .padding(.top, 16.scale)
                .padding(.bottom, 8.scale)
                .background(Tokens.Color.surfaceWhite)
        }
        .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
        .sheet(
            item: Binding(
                get: { viewModel.presentedWebDestination },
                set: { destination in
                    if destination == nil {
                        viewModel.dismissPresentedWebDestination()
                    }
                }
            )
        ) { destination in
            SafariView(url: destination.url)
        }
        .sheet(
            item: Binding(
                get: { viewModel.mailComposerPayload },
                set: { payload in
                    if payload == nil {
                        viewModel.dismissMailComposer()
                    }
                }
            )
        ) { payload in
            MailComposerView(payload: payload)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isSharePresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissShareSheet()
                    }
                }
            )
        ) {
            ShareSheet(activityItems: viewModel.shareItems)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isPremiumPaywallPresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissPremiumPaywall()
                    }
                }
            )
        ) {
            PaywallView(onClose: {
                viewModel.dismissPremiumPaywall()
            })
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isRateUsPresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissRateUs()
                    }
                }
            )
        ) {
            RateUsView(
                viewModel: resolver.resolve(RateUsViewModel.self) ?? .fallback
            )
        }
        .alert(
            item: Binding(
                get: { viewModel.alertModel },
                set: { alert in
                    if alert == nil {
                        viewModel.dismissAlert()
                    }
                }
            )
        ) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.dismissAlert()
                }
            )
        }
        .task {
            viewModel.refreshPushNotificationsState()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            viewModel.refreshPushNotificationsState()
        }
    }

    private var headerView: some View {
        Text("Settings")
            .font(Tokens.Font.outfitBold28)
            .foregroundStyle(Tokens.Color.inkPrimary)
            .kerning(-0.28.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionView(_ section: RootSettingsSceneViewModel.SectionModel) -> some View {
        VStack(spacing: 8.scale) {
            ForEach(section.rows) { row in
                Button {
                    viewModel.handleTap(row.id)
                } label: {
                    rowContent(row)
                }
                .buttonStyle(.plain)
                .disabled(!row.isEnabled)
                .opacity(row.isEnabled ? 1.0 : 0.65)
            }
        }
    }

    private func rowContent(_ row: RootSettingsSceneViewModel.RowModel) -> some View {
        HStack(spacing: 8.scale) {
            rowIcon(row)

            Text(row.title)
                .font(Tokens.Font.medium16)
                .foregroundStyle(textColor(for: row.style))
                .kerning(0.16.scale)
                .lineLimit(1)

            Spacer(minLength: 8.scale)

            switch row.accessory {
            case .chevron:
                Image("chevronRight")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20.scale, height: 20.scale)
                    .foregroundStyle(chevronColor(for: row.style))

            case .toggle(let isOn):
                SettingsPushToggle(isOn: isOn)
            }
        }
        .padding(.horizontal, 16.scale)
        .frame(height: 52.scale)
        .background(backgroundColor(for: row.style))
        .clipShape(RoundedRectangle(cornerRadius: 16.scale, style: .continuous))
    }

    @ViewBuilder
    private func rowIcon(_ row: RootSettingsSceneViewModel.RowModel) -> some View {
        if let assetIconName = row.assetIconName {
            Image(assetIconName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20.scale, height: 20.scale)
                .foregroundStyle(iconColor(for: row.style))
        } else if let systemIconName = row.systemIconName {
            Image(systemName: systemIconName)
                .resizable()
                .scaledToFit()
                .frame(width: 20.scale, height: 20.scale)
                .foregroundStyle(iconColor(for: row.style))
        }
    }

    private func backgroundColor(for style: RootSettingsSceneViewModel.RowStyle) -> Color {
        switch style {
        case .accent:
            return Tokens.Color.accent
        case .neutral:
            return Tokens.Color.cardSoftBackground
        }
    }

    private func iconColor(for style: RootSettingsSceneViewModel.RowStyle) -> Color {
        switch style {
        case .accent:
            return Tokens.Color.surfaceWhite
        case .neutral:
            return Tokens.Color.accent
        }
    }

    private func textColor(for style: RootSettingsSceneViewModel.RowStyle) -> Color {
        switch style {
        case .accent:
            return Tokens.Color.surfaceWhite
        case .neutral:
            return Tokens.Color.inkPrimary
        }
    }

    private func chevronColor(for style: RootSettingsSceneViewModel.RowStyle) -> Color {
        switch style {
        case .accent:
            return Tokens.Color.surfaceWhite
        case .neutral:
            return Tokens.Color.inkPrimary30
        }
    }
}

private struct SettingsPushToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule(style: .continuous)
                .fill(trackColor)
                .frame(width: 48.scale, height: 28.scale)

            Circle()
                .fill(knobColor)
                .frame(width: 24.scale, height: 24.scale)
                .padding(2.scale)
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    private var trackColor: Color {
        if isOn {
            return Tokens.Color.accent.opacity(0.20)
        }
        return Color(hex: "EEEEEE") ?? Tokens.Color.cardSoftBackground
    }

    private var knobColor: Color {
        if isOn {
            return Tokens.Color.accent
        }
        return Color(hex: "D8D8D8") ?? Tokens.Color.inkPrimary30
    }
}
