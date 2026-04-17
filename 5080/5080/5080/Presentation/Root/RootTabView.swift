import SwiftUI
import Swinject
import Dispatch

struct RootTabView: View {
    @Environment(\.resolver) private var resolver

    var body: some View {
        RootTabContentView(viewModel: resolver.resolve(RootTabViewModel.self) ?? .fallback)
    }
}

private struct RootTabContentView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.resolver) private var resolver
    @StateObject private var viewModel: RootTabViewModel
    @State private var textToVideoFlowSessionID = UUID()
    @State private var animateImageFlowSessionID = UUID()
    @State private var frameToVideoFlowSessionID = UUID()
    @State private var voiceGenFlowSessionID = UUID()
    @State private var transcribeFlowSessionID = UUID()
    @State private var aiImageFlowSessionID = UUID()

    init(viewModel: RootTabViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let rateUsScheduler = resolver.resolve(RateUsScheduler.self) ?? RateUsScheduler()

        ZStack(alignment: .bottom) {
            switch viewModel.selectedTab {
            case .home:
                RootHomeSceneView(viewModel: viewModel.homeViewModel)
            case .history:
                RootHistorySceneView(viewModel: viewModel.historyViewModel)
            case .settings:
                RootSettingsSceneView(viewModel: viewModel.settingsViewModel)
            }

            if viewModel.isModeSheetPresented {
                RootHomeModeSheetOverlayView(
                    viewModel: viewModel.homeViewModel,
                    isVisible: viewModel.isModeSheetVisible,
                    dragOffset: viewModel.modeSheetDragOffset,
                    onDismiss: {
                        dismissModeSheet()
                    },
                    onSelectMode: { option in
                        if option.isTextToVideo {
                            dismissModeSheet {
                                textToVideoFlowSessionID = UUID()
                                viewModel.presentTextToVideoFlow()
                            }
                            return
                        }

                        if option.isAnimateImage {
                            dismissModeSheet {
                                animateImageFlowSessionID = UUID()
                                viewModel.presentAnimateImageFlow()
                            }
                            return
                        }

                        if option.isFrameToVideo {
                            dismissModeSheet {
                                frameToVideoFlowSessionID = UUID()
                                viewModel.presentFrameToVideoFlow()
                            }
                            return
                        }

                        if option.isVoiceGen {
                            dismissModeSheet {
                                voiceGenFlowSessionID = UUID()
                                viewModel.presentVoiceGenFlow()
                            }
                            return
                        }

                        if option.isTranscribe {
                            dismissModeSheet {
                                transcribeFlowSessionID = UUID()
                                viewModel.presentTranscribeFlow()
                            }
                            return
                        }

                        if option.isAIImage {
                            dismissModeSheet {
                                aiImageFlowSessionID = UUID()
                                viewModel.presentAIImageFlow()
                            }
                            return
                        }

                        dismissModeSheet()
                    },
                    onDragChanged: { translationHeight in
                        viewModel.updateModeSheetDrag(translationHeight: translationHeight)
                    },
                    onDragEnded: { translationHeight in
                        if viewModel.shouldDismissModeSheet(for: translationHeight) {
                            dismissModeSheet()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                viewModel.resetModeSheetDrag()
                            }
                        }
                    }
                )
                .onAppear {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        viewModel.completeModeSheetPresentation()
                    }
                }
                .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !viewModel.isModeSheetPresented {
                RootMainTabBar(
                    selectedTab: $viewModel.selectedTab,
                    onTapPlus: {
                        viewModel.prepareModeSheetPresentation()
                    }
                )
                .padding(.bottom, 8.scale)
                .background(Color.clear)
            }
        }
        .background(Tokens.Color.surfaceWhite.ignoresSafeArea())
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
            get: { viewModel.isTextToVideoFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissTextToVideoFlow()
                }
            }
        )) {
            TextToVideoFlowView(
                viewModel: resolver.resolve(TextToVideoFlowViewModel.self, argument: viewModel.textToVideoLaunchPrompt) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.textToVideo,
                onClose: {
                    viewModel.dismissTextToVideoFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .textToVideo, to: option)
                }
            )
            .id(textToVideoFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isAnimateImageFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissAnimateImageFlow()
                }
            }
        )) {
            AnimateImageFlowView(
                viewModel: resolver.resolve(AnimateImageFlowViewModel.self, argument: viewModel.animateImageLaunchPrompt) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.animateImage,
                onClose: {
                    viewModel.dismissAnimateImageFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .animateImage, to: option)
                }
            )
            .id(animateImageFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isFrameToVideoFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissFrameToVideoFlow()
                }
            }
        )) {
            FrameToVideoFlowView(
                viewModel: resolver.resolve(FrameToVideoFlowViewModel.self, argument: viewModel.frameToVideoLaunchPrompt) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.frameToVideo,
                onClose: {
                    viewModel.dismissFrameToVideoFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .frameToVideo, to: option)
                }
            )
            .id(frameToVideoFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isVoiceGenFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissVoiceGenFlow()
                }
            }
        )) {
            VoiceGenFlowView(
                viewModel: resolver.resolve(VoiceGenFlowViewModel.self) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.voiceGen,
                onClose: {
                    viewModel.dismissVoiceGenFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .voiceGen, to: option)
                }
            )
            .id(voiceGenFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isTranscribeFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissTranscribeFlow()
                }
            }
        )) {
            TranscribeFlowView(
                viewModel: resolver.resolve(TranscribeFlowViewModel.self) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.transcribe,
                onClose: {
                    viewModel.dismissTranscribeFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .transcribe, to: option)
                }
            )
            .id(transcribeFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isAIImageFlowPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissAIImageFlow()
                }
            }
        )) {
            AIImageFlowView(
                viewModel: resolver.resolve(AIImageFlowViewModel.self, argument: viewModel.aiImageLaunchPrompt) ?? .fallback,
                rateUsScheduler: rateUsScheduler,
                modeSections: viewModel.homeViewModel.modeSections,
                currentModeID: RootHomeModeOptionID.aiImage,
                onClose: {
                    viewModel.dismissAIImageFlow()
                },
                onSelectMode: { option in
                    switchComposerMode(from: .aiImage, to: option)
                }
            )
            .id(aiImageFlowSessionID)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isSubscriptionPaywallPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSubscriptionPaywall()
                }
            }
        )) {
            PaywallView(onClose: {
                viewModel.dismissSubscriptionPaywall()
            })
            .environmentObject(purchaseManager)
        }
    }

    private func dismissModeSheet(completion: (() -> Void)? = nil) {
        guard viewModel.isModeSheetPresented, viewModel.isModeSheetVisible else { return }

        withAnimation(.easeInOut(duration: 0.24)) {
            viewModel.beginModeSheetDismissal()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            viewModel.completeModeSheetDismissal()
            completion?()
        }
    }

    private func switchComposerMode(from currentFlow: HistoryFlowKind, to option: RootHomeModeOption) {
        let targetFlow = option.flowKind
        guard targetFlow != currentFlow else { return }

        dismissComposerFlow(currentFlow)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            presentComposerFlow(targetFlow)
        }
    }

    private func dismissComposerFlow(_ flow: HistoryFlowKind) {
        switch flow {
        case .textToVideo:
            viewModel.dismissTextToVideoFlow()
        case .animateImage:
            viewModel.dismissAnimateImageFlow()
        case .frameToVideo:
            viewModel.dismissFrameToVideoFlow()
        case .voiceGen:
            viewModel.dismissVoiceGenFlow()
        case .transcribe:
            viewModel.dismissTranscribeFlow()
        case .aiImage:
            viewModel.dismissAIImageFlow()
        }
    }

    private func presentComposerFlow(_ flow: HistoryFlowKind) {
        switch flow {
        case .textToVideo:
            textToVideoFlowSessionID = UUID()
            viewModel.presentTextToVideoFlow()
        case .animateImage:
            animateImageFlowSessionID = UUID()
            viewModel.presentAnimateImageFlow()
        case .frameToVideo:
            frameToVideoFlowSessionID = UUID()
            viewModel.presentFrameToVideoFlow()
        case .voiceGen:
            voiceGenFlowSessionID = UUID()
            viewModel.presentVoiceGenFlow()
        case .transcribe:
            transcribeFlowSessionID = UUID()
            viewModel.presentTranscribeFlow()
        case .aiImage:
            aiImageFlowSessionID = UUID()
            viewModel.presentAIImageFlow()
        }
    }
}
