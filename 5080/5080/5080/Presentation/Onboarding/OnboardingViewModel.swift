
import Foundation
import Combine

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var slides: [OnboardingSlide]
    @Published public private(set) var isRequestingNotificationPermission = false
    @Published public private(set) var shouldRequestSystemReview = false

    public let links: OnboardingLinks

    @Published public var currentIndex: Int = 0
    private let notificationsScheduler: OnboardingNotificationsScheduling

    public init(
        contentProvider: OnboardingContentProviding? = nil,
        notificationsScheduler: OnboardingNotificationsScheduling = NoopOnboardingNotificationsScheduler()
    ) {
        let resolvedProvider = contentProvider ?? DefaultOnboardingContentProvider()
        self.slides = resolvedProvider.slides
        self.links = resolvedProvider.links
        self.notificationsScheduler = notificationsScheduler
    }

    static var fallback: OnboardingViewModel {
        OnboardingViewModel()
    }

    var isOnPaywallStep: Bool {
        currentIndex >= slides.count
    }

    func advance() async {
        let lastIndex = slides.count // The next screen after the slides is the paywall.
        guard currentIndex < lastIndex else { return }

        if slides[currentIndex].requestsSystemReviewPrompt {
            shouldRequestSystemReview = true
        }

        if slides[currentIndex].requestsNotificationPermission {
            await requestNotificationPermissionIfNeeded()
        }

        currentIndex += 1
    }

    func completeSystemReviewRequest() {
        shouldRequestSystemReview = false
    }

    func finish() {
        UserDefaults.standard.set(true, forKey: "OnBoardEnd")
    }

    private func requestNotificationPermissionIfNeeded() async {
        guard !isRequestingNotificationPermission else { return }

        isRequestingNotificationPermission = true
        defer { isRequestingNotificationPermission = false }

        await notificationsScheduler.requestAuthorizationAndScheduleWeeklyPromptsIfNeeded()
    }
}
