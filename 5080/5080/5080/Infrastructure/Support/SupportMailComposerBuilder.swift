import Foundation
import UIKit

enum AppExternalResources {
    static let supportEmail = "hassan_emily8936@aol.com"
    static let privacyPolicyURL = URL(string: "https://docs.google.com/document/d/1mqOCStt88ABwKV-g1yvsl4MgnsFKFsth3px7Ryo9lGI/edit?usp=sharing")!
    static let termsOfUseURL = URL(string: "https://docs.google.com/document/d/1d4KEY-DywWPa-tgIvnXgdh-VEAotZXfdojFCI9w-yPw/edit?usp=sharing")!
    static let supportFormURL = URL(string: "https://forms.gle/gDvGDpUYDEwRW7RD7")!
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/zentium-labs/id6762474175")!
}

enum SupportMailContext {
    case support
    case rateUsMaybeLater

    var subject: String {
        switch self {
        case .support:
            return "Zentium Labs Support"
        case .rateUsMaybeLater:
            return "Zentium Labs Feedback"
        }
    }

    var prompt: String {
        switch self {
        case .support:
            return """
            Hi,

            Please describe the issue below.
            """
        case .rateUsMaybeLater:
            return """
            Hi,

            I chose "Maybe Later" on the Rate Us screen and want to share feedback.
            """
        }
    }
}

struct SupportMailMetadata {
    let userID: String
    let availableTokens: Int
    let activePlanTitle: String?
}

protocol SupportMailComposerBuilding {
    func makePayload(
        context: SupportMailContext,
        metadata: SupportMailMetadata
    ) -> MailComposerPayload
}

final class DefaultSupportMailComposerBuilder: SupportMailComposerBuilding {
    private let bundle: Bundle
    private let supportEmail: String
    private let timestampFormatter = ISO8601DateFormatter()

    init(
        bundle: Bundle,
        supportEmail: String
    ) {
        self.bundle = bundle
        self.supportEmail = supportEmail
        self.timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func makePayload(
        context: SupportMailContext,
        metadata: SupportMailMetadata
    ) -> MailComposerPayload {
        let body = """
        \(context.prompt)

        [Write here]

        ---
        App: \(resolvedAppName())
        Version: \(resolvedVersion())
        Build: \(resolvedBuild())
        Bundle ID: \(bundle.bundleIdentifier ?? "Unknown")
        User ID: \(resolvedValue(metadata.userID))
        Active plan: \(metadata.activePlanTitle ?? "Free")
        Available tokens: \(metadata.availableTokens)
        Device: \(UIDevice.current.model)
        Device identifier: \(deviceIdentifier())
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Locale: \(Locale.current.identifier)
        Time zone: \(TimeZone.current.identifier)
        Preferred language: \(Locale.preferredLanguages.first ?? "Unknown")
        IDFV: \(UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")
        Timestamp: \(timestampFormatter.string(from: Date()))
        """

        return MailComposerPayload(
            to: supportEmail,
            subject: context.subject,
            body: body,
            isHTML: false,
            fallbackMailToURL: MailComposerPayload.makeMailToURL(
                to: supportEmail,
                subject: context.subject,
                body: body
            )
        )
    }
}

private extension DefaultSupportMailComposerBuilder {
    func resolvedAppName() -> String {
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let displayName, !displayName.isEmpty {
            return displayName
        }

        let bundleName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let bundleName, !bundleName.isEmpty {
            return bundleName
        }

        return "Zentium Labs"
    }

    func resolvedVersion() -> String {
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let version, !version.isEmpty {
            return version
        }

        return "Unknown"
    }

    func resolvedBuild() -> String {
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let build, !build.isEmpty {
            return build
        }

        return "Unknown"
    }

    func resolvedValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown" : trimmed
    }

    func deviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown" : trimmed
    }
}
