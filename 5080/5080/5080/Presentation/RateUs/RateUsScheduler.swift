import Foundation
import Combine

@MainActor
final class RateUsScheduler: ObservableObject {
    @Published private(set) var isAutomaticPromptPresented = false

    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let calendar: Calendar

    private enum Keys {
        static let totalSuccessfulResults = "rate_us_scheduler.total_successful_results"
        static let lastPromptSuccessfulResults = "rate_us_scheduler.last_prompt_successful_results"
        static let lastPromptDate = "rate_us_scheduler.last_prompt_date"
        static let lastPromptedVersion = "rate_us_scheduler.last_prompted_version"
        static let automaticPromptCount = "rate_us_scheduler.automatic_prompt_count"
        static let didSubmitReview = "rate_us_scheduler.did_submit_review"
    }

    private enum Policy {
        static let successfulResultsBetweenPrompts = 3
        static let cooldownDaysBetweenPrompts = 14
        static let maximumAutomaticPrompts = 3
    }

    init(
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        calendar: Calendar = .current
    ) {
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.calendar = calendar
    }

    func registerSuccessfulResult() {
        let totalSuccessfulResults = userDefaults.integer(forKey: Keys.totalSuccessfulResults) + 1
        userDefaults.set(totalSuccessfulResults, forKey: Keys.totalSuccessfulResults)

        guard shouldPresentAutomaticPrompt(totalSuccessfulResults: totalSuccessfulResults) else { return }

        userDefaults.set(totalSuccessfulResults, forKey: Keys.lastPromptSuccessfulResults)
        userDefaults.set(Date(), forKey: Keys.lastPromptDate)
        userDefaults.set(currentAppVersion, forKey: Keys.lastPromptedVersion)
        userDefaults.set(
            userDefaults.integer(forKey: Keys.automaticPromptCount) + 1,
            forKey: Keys.automaticPromptCount
        )

        isAutomaticPromptPresented = true
    }

    func dismissAutomaticPrompt() {
        isAutomaticPromptPresented = false
    }

    func markReviewSubmitted() {
        userDefaults.set(true, forKey: Keys.didSubmitReview)
        isAutomaticPromptPresented = false
    }
}

private extension RateUsScheduler {
    func shouldPresentAutomaticPrompt(totalSuccessfulResults: Int) -> Bool {
        guard !isAutomaticPromptPresented else { return false }
        guard !userDefaults.bool(forKey: Keys.didSubmitReview) else { return false }
        guard userDefaults.integer(forKey: Keys.automaticPromptCount) < Policy.maximumAutomaticPrompts else { return false }

        if totalSuccessfulResults == 1 {
            return true
        }

        let lastPromptSuccessfulResults = userDefaults.integer(forKey: Keys.lastPromptSuccessfulResults)
        guard totalSuccessfulResults - lastPromptSuccessfulResults >= Policy.successfulResultsBetweenPrompts else {
            return false
        }

        if let lastPromptedVersion = userDefaults.string(forKey: Keys.lastPromptedVersion),
           lastPromptedVersion == currentAppVersion {
            return false
        }

        if let lastPromptDate = userDefaults.object(forKey: Keys.lastPromptDate) as? Date,
           let nextAllowedDate = calendar.date(byAdding: .day, value: Policy.cooldownDaysBetweenPrompts, to: lastPromptDate),
           Date() < nextAllowedDate {
            return false
        }

        return true
    }

    var currentAppVersion: String {
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let version, !version.isEmpty {
            return version
        }

        return "unknown"
    }
}
