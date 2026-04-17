import SwiftUI
import UIKit
import StoreKit

public struct OnboardingView: View {
    @StateObject private var vm: OnboardingViewModel

    private let onFinish: () -> Void

    @State private var activeSheet: OnboardingSheet?
    @State private var isRestoring: Bool = false
    @State private var restoreAlertTitle: String = ""
    @State private var restoreAlertText: String?
    @State private var didTrackOnboardingStart: Bool = false

    @StateObject private var purchaseManager = PurchaseManager.shared

    public init(vm: OnboardingViewModel, onFinish: @escaping () -> Void = {}) {
        _vm = StateObject(wrappedValue: vm)
        self.onFinish = onFinish
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if vm.isOnPaywallStep {
                    paywallHostView
                        .id("paywall")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    onboardingSlidesImageStrip(in: proxy)
                }

                if vm.currentIndex < vm.slides.count {
                    let slide = vm.slides[vm.currentIndex]
                    OnboardingBottomCardView(
                        title: slide.title,
                        subtitle: slide.subtitle,
                        bottomSafeInset: proxy.safeAreaInsets.bottom,
                        isPrimaryLoading: isPrimaryButtonLoading,
                        onPrimaryTap: {
                            handlePrimaryTap()
                        },
                        onOpenTerms: {
                            openSafari(vm.links.termsURL)
                        },
                        onRestoreTap: {
                            Task { await restorePurchases() }
                        },
                        onOpenPrivacy: {
                            openSafari(vm.links.privacyURL)
                        }
                    )
                    .frame(width: proxy.size.width)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .background(
                Group {
                    if vm.isOnPaywallStep {
                        Color.clear
                    } else {
                        onboardingBackgroundView
                    }
                }
            )
            .animation(
                .interactiveSpring(
                    response: 0.45,
                    dampingFraction: 0.88,
                    blendDuration: 0.2
                ),
                value: vm.isOnPaywallStep
            )
            .ignoresSafeArea(.all)
        }
        .onAppear {
            guard !didTrackOnboardingStart else { return }
            didTrackOnboardingStart = true
            Analytics.shared.track("onboarding_start")
            applyWindowInterfaceStyle(.dark)
        }
        .onDisappear {
            applyWindowInterfaceStyle(.light)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .safari(let url):
                SafariView(url: url)
            }
        }
        .alert(
            restoreAlertTitle,
            isPresented: Binding(
                get: { restoreAlertText != nil },
                set: { _ in restoreAlertText = nil }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreAlertText ?? "")
        }
        .onChange(of: purchaseManager.isSubscribed) { _, newValue in
            guard newValue else { return }
            guard vm.isOnPaywallStep else { return }
            finishOnboarding()
        }
        .onChange(of: vm.isOnPaywallStep) { _, isOnPaywallStep in
            applyWindowInterfaceStyle(isOnPaywallStep ? .light : .dark)
        }
        .onChange(of: vm.shouldRequestSystemReview) { _, shouldRequestSystemReview in
            guard shouldRequestSystemReview else { return }
            requestSystemReview()
            vm.completeSystemReviewRequest()
        }
        .preferredColorScheme(vm.isOnPaywallStep ? .light : .dark)
    }
}

private extension OnboardingView {
    enum OnboardingAssets {
        static let backgroundImageName = "Onboarding.Background"
    }

    var slideMovementAnimation: Animation {
        .interactiveSpring(
            response: 0.45,
            dampingFraction: 0.88,
            blendDuration: 0.2
        )
    }

    var isPrimaryButtonLoading: Bool {
        vm.isRequestingNotificationPermission
    }

    func handlePrimaryTap() {
        Task {
            await vm.advance()
        }
    }

    @ViewBuilder
    var paywallHostView: some View {
        PaywallView(onClose: {
            finishOnboarding()
        })
        .environment(\.dynamicTypeSize, .small)
        .environmentObject(purchaseManager)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
    }

    func finishOnboarding() {
        vm.finish()
        onFinish()
    }

    func openSafari(_ url: URL) {
        activeSheet = .safari(url)
    }

    @MainActor
    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        Analytics.shared.track("onboarding_restore_tap_appstore")

        let isRussianUI = Locale.current.language.languageCode?.identifier == "ru"
        let ok = await purchaseManager.restoreAny()
        restoreAlertTitle = isRussianUI ? "Восстановление покупок" : "Restore Purchases"

        if ok {
            restoreAlertText = isRussianUI
            ? "Покупки успешно восстановлены"
            : "Purchases restored successfully"
            return
        }

        restoreAlertText = restoreFailureMessage(isRussianUI: isRussianUI)
    }

    @MainActor
    func restoreFailureMessage(isRussianUI: Bool) -> String {
        let alreadyActiveSuffix = isRussianUI
        ? "Подписка уже активна и работает в приложении."
        : "Your subscription is already active and available in the app."

        let defaultNothing = isRussianUI ? "Нечего восстанавливать" : "Nothing to restore"
        let raw = (purchaseManager.failRestoreText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if purchaseManager.isSubscribed {
            if raw.isEmpty || raw.lowercased() == "nothing to restore" {
                return "\(defaultNothing). \(alreadyActiveSuffix)"
            }
            return "\(raw)\n\(alreadyActiveSuffix)"
        }

        return raw.isEmpty ? defaultNothing : raw
    }

    func applyWindowInterfaceStyle(_ style: UIUserInterfaceStyle) {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    func requestSystemReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        AppStore.requestReview(in: windowScene)
    }

    @ViewBuilder
    var onboardingBackgroundView: some View {
        if let uiImage = UIImage(named: OnboardingAssets.backgroundImageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea(.all)
        } else {
            Tokens.Color.inkPrimary
                .ignoresSafeArea(.all)
        }
    }

    @ViewBuilder
    func onboardingSlidesImageStrip(in proxy: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(vm.slides) { slide in
                onboardingSlideImageView(slide)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        .offset(x: -CGFloat(vm.currentIndex) * proxy.size.width)
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
        .animation(slideMovementAnimation, value: vm.currentIndex)
    }

    @ViewBuilder
    func onboardingSlideImageView(_ slide: OnboardingSlide) -> some View {
        let layoutType = DeviceLayout.type
        let baseScale = slide.scale.resolve(for: layoutType)
        let slideScale = onboardingSlideImageScale(for: slide.id, layoutType: layoutType)
        let resolvedTopOffset = onboardingSlideImageTopOffset(for: slide.id, layoutType: layoutType)
        Image(slide.imageName)
            .resizable()
            .scaledToFit()
            .frame(
                width: slide.imageWidth * baseScale.x * slideScale,
                height: slide.imageHeight * baseScale.y * slideScale
            )
            .padding(.top, resolvedTopOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    func onboardingSlideImageScale(for slideID: Int, layoutType: DeviceLayoutType) -> CGFloat {
        let isIpad = layoutType == .iPad || layoutType == .unknown || layoutType == .smallStatusBar

        switch slideID {
        case 0:
            return isIpad ? 0.8 : 1
        case 1:
            return isIpad ? 0.8 : 1
        case 2:
            return isIpad ? 0.7 : 1
        default:
            return 1
        }
    }

    func onboardingSlideImageTopOffset(for slideID: Int, layoutType: DeviceLayoutType) -> CGFloat {
        let isIpad = layoutType == .iPad || layoutType == .unknown || layoutType == .smallStatusBar

        switch slideID {
        case 0:
            return isIpad ? -30.scale : 0.scale
        case 1:
            return isIpad ? -70.scale : -50.scale
        case 2:
            return isIpad ? -45.scale : -58.scale
        default:
            return 0.scale
        }
    }
}
