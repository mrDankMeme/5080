import SwiftUI
import Dispatch
import Swinject

struct VoiceGenFlowView: View {
    @Environment(\.resolver) private var resolver
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var viewModel: VoiceGenFlowViewModel
    @ObservedObject private var rateUsScheduler: RateUsScheduler
    private let modeSections: [RootHomeModeSection]
    private let currentModeID: String
    private let onClose: () -> Void
    private let onSelectMode: (RootHomeModeOption) -> Void

    @State private var isModePickerPresented = false
    @State private var isModePickerVisible = false
    @State private var modePickerDragOffset: CGFloat = 0.scale
    @State private var isAIProcessingConsentPresented = false

    init(
        viewModel: VoiceGenFlowViewModel,
        rateUsScheduler: RateUsScheduler,
        modeSections: [RootHomeModeSection],
        currentModeID: String,
        onClose: @escaping () -> Void,
        onSelectMode: @escaping (RootHomeModeOption) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _rateUsScheduler = ObservedObject(wrappedValue: rateUsScheduler)
        self.modeSections = modeSections
        self.currentModeID = currentModeID
        self.onClose = onClose
        self.onSelectMode = onSelectMode
    }

    var body: some View {
        ZStack {
            switch viewModel.route {
            case .composer:
                VoiceGenSceneView(
                    viewModel: viewModel.sceneViewModel,
                    isSubscribed: viewModel.isSubscribed,
                    onBack: onClose,
                    onTapModeTitle: presentModePicker,
                    onTapBalanceAccessory: {
                        viewModel.handleBalanceTap()
                    },
                    onGenerate: {
                        handleGenerateTap()
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))

            case .loading:
                TextToVideoLoadingSceneView(
                    viewModel: viewModel.loadingViewModel,
                    onBack: onClose
                )
                .transition(.opacity)

            case .result:
                if let resultViewModel = viewModel.resultViewModel {
                    VoiceGenResultSceneView(
                        viewModel: resultViewModel,
                        onBack: {
                            viewModel.closeResult()
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Tokens.Color.surfaceWhite.ignoresSafeArea()
                }

            case .failed:
                TextToVideoFailedSceneView(
                    viewModel: viewModel.failedViewModel,
                    onBack: {
                        onClose()
                    },
                    onTryAgain: {
                        viewModel.retryAfterFailure()
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if isModePickerPresented {
                RootModePickerOverlayView(
                    sheetTitle: "Select Mode",
                    modeSections: modeSections,
                    selectedModeID: currentModeID,
                    isVisible: isModePickerVisible,
                    dragOffset: modePickerDragOffset,
                    onDismiss: {
                        dismissModePicker()
                    },
                    onSelectMode: { option in
                        dismissModePicker {
                            onSelectMode(option)
                        }
                    },
                    onDragChanged: { translationHeight in
                        modePickerDragOffset = max(0.scale, translationHeight)
                    },
                    onDragEnded: { translationHeight in
                        if translationHeight > 120.scale {
                            dismissModePicker()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                modePickerDragOffset = 0.scale
                            }
                        }
                    }
                )
                .zIndex(30)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: viewModel.route)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.route) { _, route in
            guard route == .result else { return }
            rateUsScheduler.registerSuccessfulResult()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isTokensPaywallPresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissTokensPaywall()
                    }
                }
            )
        ) {
            TokensPaywallView {
                viewModel.dismissTokensPaywall()
            }
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.isSubscriptionPaywallPresented },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissSubscriptionPaywall()
                    }
                }
            )
        ) {
            PaywallView(onClose: {
                viewModel.dismissSubscriptionPaywall()
            })
            .environmentObject(purchaseManager)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { rateUsScheduler.isAutomaticPromptPresented },
                set: { isPresented in
                    if !isPresented {
                        rateUsScheduler.dismissAutomaticPrompt()
                    }
                }
            )
        ) {
            RateUsView(
                viewModel: resolver.resolve(RateUsViewModel.self) ?? .fallback
            )
        }
        .alert(
            AIProcessingConsentAlertContent.title,
            isPresented: $isAIProcessingConsentPresented
        ) {
            Button(AIProcessingConsentAlertContent.cancelButtonTitle, role: .cancel) {}
            Button(AIProcessingConsentAlertContent.agreeButtonTitle) {
                viewModel.acceptAIProcessingConsent()
                viewModel.startGeneration()
            }
        } message: {
            Text(AIProcessingConsentAlertContent.message)
        }
    }

    private func presentModePicker() {
        guard !isModePickerPresented else { return }

        modePickerDragOffset = 0.scale
        isModePickerPresented = true

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isModePickerVisible = true
        }
    }

    private func dismissModePicker(completion: (() -> Void)? = nil) {
        guard isModePickerPresented else {
            completion?()
            return
        }

        withAnimation(.easeInOut(duration: 0.24)) {
            isModePickerVisible = false
            modePickerDragOffset = 0.scale
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            isModePickerPresented = false
            completion?()
        }
    }

    private func handleGenerateTap() {
        guard viewModel.hasAcceptedAIProcessingConsent else {
            isAIProcessingConsentPresented = true
            return
        }

        viewModel.startGeneration()
    }
}
