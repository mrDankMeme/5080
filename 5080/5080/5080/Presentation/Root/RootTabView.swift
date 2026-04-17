import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @StateObject private var viewModel: RootTabViewModel

    init(viewModel: RootTabViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Base44HomeSceneView(
            viewModel: viewModel.homeViewModel,
            onTapSettings: {
                viewModel.openSettings()
            },
            onTapPro: {
                viewModel.openPro()
            },
            onTapCreate: {
                viewModel.openCreate()
            },
            onTapProject: { project in
                viewModel.openProject(project)
            }
        )
        .task {
            await viewModel.loadHomeIfNeeded()
        }
        .fullScreenCover(
            item: Binding(
                get: { viewModel.builderPresentation },
                set: { presentation in
                    if presentation == nil {
                        viewModel.dismissBuilder()
                    }
                }
            ),
            onDismiss: {
                Task {
                    await viewModel.refreshProjects()
                }
            }
        ) { context in
            BuilderWorkspaceSceneView(
                viewModel: viewModel.makeBuilderViewModel(
                    for: context.launch
                )
            )
        }
        .fullScreenCover(
            item: Binding(
                get: { viewModel.sitePreviewViewModel },
                set: { previewViewModel in
                    if previewViewModel == nil {
                        viewModel.dismissSitePreview()
                    }
                }
            )
        ) { previewViewModel in
            SitePreviewSceneView(viewModel: previewViewModel)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isSubscriptionPaywallPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSubscriptionPaywall()
                }
            }
        )) {
            PaywallView {
                viewModel.dismissSubscriptionPaywall()
            }
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isTokensPaywallPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissTokensPaywall()
                }
            }
        )) {
            TokensPaywallView {
                viewModel.dismissTokensPaywall()
            }
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isSettingsPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSettings()
                }
            }
        )) {
            RootSettingsContainerView(viewModel: viewModel.settingsViewModel)
        }
    }
}

private struct RootSettingsContainerView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: RootSettingsSceneViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RootSettingsSceneView(viewModel: viewModel)

            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Tokens.Color.surfaceWhite.opacity(0.96))
                    .frame(width: 40.scale, height: 40.scale)
                    .overlay {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14.scale, height: 14.scale)
                            .foregroundStyle(Tokens.Color.inkPrimary)
                    }
                    .shadow(
                        color: Tokens.Color.inkPrimary.opacity(0.08),
                        radius: 10.scale,
                        y: 2.scale
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 14.scale)
            .padding(.trailing, 16.scale)
        }
        .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
    }
}
