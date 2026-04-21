import Foundation
import UserNotifications

public enum WeeklyPromptsToggleResult {
    case enabled
    case disabled
    case requiresSystemSettings
}

public protocol OnboardingNotificationsScheduling {
    func requestAuthorizationAndScheduleWeeklyPromptsIfNeeded() async
    func setWeeklyPromptsEnabled(_ isEnabled: Bool) async -> WeeklyPromptsToggleResult
    func notificationsEnabled() async -> Bool
    func syncScheduledWeeklyPromptsIfNeeded() async
}

public struct NoopOnboardingNotificationsScheduler: OnboardingNotificationsScheduling {
    public nonisolated init() {}

    public nonisolated func requestAuthorizationAndScheduleWeeklyPromptsIfNeeded() async {}

    public nonisolated func setWeeklyPromptsEnabled(_ isEnabled: Bool) async -> WeeklyPromptsToggleResult {
        .disabled
    }

    public nonisolated func notificationsEnabled() async -> Bool {
        false
    }

    public nonisolated func syncScheduledWeeklyPromptsIfNeeded() async {}
}

final class WeeklyOnboardingNotificationsScheduler: OnboardingNotificationsScheduling {
    private struct PromptCopy {
        let title: String
        let body: String
    }

    private enum Constants {
        static let requestIdentifierPrefix = "onboarding.weekly.prompt"
        static let scheduledWeeksCount = 52
        static let deliveryHour = 19
        static let deliveryMinute = 0
        static let weekInterval: TimeInterval = 7 * 24 * 60 * 60
        static let anchorDateKey = "onboarding.weekly.prompt.anchorDate"
    }

    private let center: UNUserNotificationCenter
    private var calendar: Calendar
    private let userDefaults: UserDefaults

    private let promptCopies: [PromptCopy] = [
        PromptCopy(
            title: "An idea for your next masterpiece 💡",
            body: "\"Cyberpunk city in the rain\" - enter this prompt and see what happens!"
        ),
        PromptCopy(
            title: "Did you know you can... 🤔",
            body: "...upload your own photos and animate them? Give it a try ->"
        ),
        PromptCopy(
            title: "Need content for social media? 📱",
            body: "Generate unique covers and stories in one tap."
        )
    ]

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.center = center
        self.calendar = calendar
        self.calendar.timeZone = .current
        self.userDefaults = userDefaults
    }

    func requestAuthorizationAndScheduleWeeklyPromptsIfNeeded() async {
        _ = await setWeeklyPromptsEnabled(true)
    }

    func setWeeklyPromptsEnabled(_ isEnabled: Bool) async -> WeeklyPromptsToggleResult {
        guard isEnabled else {
            clearAnchorDate()
            await removeManagedRequests()
            return .disabled
        }

        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            let anchorDate = resolvedAnchorDate(for: Date())
            await scheduleWeeklyPrompts(anchorDate: anchorDate, now: Date())
            return .enabled
        case .notDetermined:
            let isGranted = await requestAuthorization()
            guard isGranted else { return .disabled }

            let anchorDate = resolvedAnchorDate(for: Date())
            await scheduleWeeklyPrompts(anchorDate: anchorDate, now: Date())
            return .enabled
        case .denied:
            return .requiresSystemSettings
        @unknown default:
            return .disabled
        }
    }

    func notificationsEnabled() async -> Bool {
        let settings = await notificationSettings()
        guard authorizationGranted(for: settings.authorizationStatus) else { return false }
        return await storedOrInferredAnchorDate() != nil
    }

    func syncScheduledWeeklyPromptsIfNeeded() async {
        let settings = await notificationSettings()
        guard authorizationGranted(for: settings.authorizationStatus) else { return }
        guard let anchorDate = await storedOrInferredAnchorDate() else { return }
        await scheduleWeeklyPrompts(anchorDate: anchorDate, now: Date())
    }
}

private extension WeeklyOnboardingNotificationsScheduler {
    func scheduleWeeklyPrompts(anchorDate: Date, now: Date) async {
        await removeManagedRequests()

        let startWeekIndex = upcomingWeekIndex(now: now, anchorDate: anchorDate)

        for weekOffset in 0..<Constants.scheduledWeeksCount {
            let weekIndex = startWeekIndex + weekOffset
            guard let deliveryDate = deliveryDate(for: weekIndex, anchorDate: anchorDate) else {
                continue
            }

            let prompt = promptCopies[weekIndex % promptCopies.count]
            let content = UNMutableNotificationContent()
            content.title = prompt.title
            content.body = prompt.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: deliveryDate
                ),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier(for: weekIndex),
                content: content,
                trigger: trigger
            )

            await add(request)
        }
    }

    func identifier(for weekIndex: Int) -> String {
        "\(Constants.requestIdentifierPrefix).\(weekIndex)"
    }

    func firstDeliveryDate(from now: Date) -> Date {
        let oneWeekLater = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 60 * 60)
        let alignedDate = calendar.date(
            bySettingHour: Constants.deliveryHour,
            minute: Constants.deliveryMinute,
            second: 0,
            of: oneWeekLater
        ) ?? oneWeekLater

        if alignedDate >= oneWeekLater {
            return alignedDate
        }

        return calendar.date(byAdding: .day, value: 1, to: alignedDate) ?? oneWeekLater
    }

    func resolvedAnchorDate(for now: Date) -> Date {
        if let storedAnchorDate = userDefaults.object(forKey: Constants.anchorDateKey) as? Date {
            return storedAnchorDate
        }

        let anchorDate = firstDeliveryDate(from: now)
        userDefaults.set(anchorDate, forKey: Constants.anchorDateKey)
        return anchorDate
    }

    func storedOrInferredAnchorDate() async -> Date? {
        if let storedAnchorDate = userDefaults.object(forKey: Constants.anchorDateKey) as? Date {
            return storedAnchorDate
        }

        let pendingRequests = await pendingRequests()
        let managedRequests = pendingRequests.compactMap { request -> (weekIndex: Int, nextDate: Date)? in
            guard let weekIndex = weekIndex(from: request.identifier),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let nextDate = trigger.nextTriggerDate() else {
                return nil
            }

            return (weekIndex, nextDate)
        }

        guard let earliestRequest = managedRequests.min(by: { $0.nextDate < $1.nextDate }) else {
            return nil
        }

        let anchorDate = calendar.date(byAdding: .weekOfYear, value: -earliestRequest.weekIndex, to: earliestRequest.nextDate)
            ?? earliestRequest.nextDate.addingTimeInterval(-Double(earliestRequest.weekIndex) * Constants.weekInterval)
        userDefaults.set(anchorDate, forKey: Constants.anchorDateKey)
        return anchorDate
    }

    func clearAnchorDate() {
        userDefaults.removeObject(forKey: Constants.anchorDateKey)
    }

    func weekIndex(from identifier: String) -> Int? {
        let prefix = "\(Constants.requestIdentifierPrefix)."
        guard identifier.hasPrefix(prefix) else { return nil }
        return Int(identifier.dropFirst(prefix.count))
    }

    func deliveryDate(for weekIndex: Int, anchorDate: Date) -> Date? {
        calendar.date(byAdding: .weekOfYear, value: weekIndex, to: anchorDate)
    }

    func upcomingWeekIndex(now: Date, anchorDate: Date) -> Int {
        guard now > anchorDate else { return 0 }

        var weekIndex = max(0, Int(floor(now.timeIntervalSince(anchorDate) / Constants.weekInterval)))

        while let deliveryDate = deliveryDate(for: weekIndex, anchorDate: anchorDate),
              deliveryDate < now {
            weekIndex += 1
        }

        while weekIndex > 0,
              let previousDeliveryDate = deliveryDate(for: weekIndex - 1, anchorDate: anchorDate),
              previousDeliveryDate >= now {
            weekIndex -= 1
        }

        return weekIndex
    }

    func authorizationGranted(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func deliveredNotificationIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                let identifiers = notifications
                    .map(\.request.identifier)
                    .filter { $0.hasPrefix(Constants.requestIdentifierPrefix) }
                continuation.resume(returning: identifiers)
            }
        }
    }

    func removeManagedRequests() async {
        let pendingIdentifiers = await pendingRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Constants.requestIdentifierPrefix) }
        let deliveredIdentifiers = await deliveredNotificationIdentifiers()
        let identifiers = Array(Set(pendingIdentifiers + deliveredIdentifiers))

        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, _ in
                continuation.resume(returning: isGranted)
            }
        }
    }

    func add(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }
}
