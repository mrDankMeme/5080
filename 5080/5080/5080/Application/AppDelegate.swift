import UIKit
import AppTrackingTransparency
import AdSupport
import OSLog
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestATT()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    private func requestATT() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                _ = ASIdentifierManager.shared().advertisingIdentifier
            }
        }
    }
}

final class Analytics {
    static let shared = Analytics()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.yev5080base44", category: "analytics")

    private init() {}

    func track(_ event: String) {
        logger.debug("track event=\(event, privacy: .public)")
    }
}
