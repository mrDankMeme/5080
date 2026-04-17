
import Foundation
import CoreGraphics

public struct OnboardingSlide: Equatable, Identifiable {
    public let id: Int
    public let imageName: String
    public let imageWidth: CGFloat
    public let imageHeight: CGFloat
    public let imageTopOffset: CGFloat
    public let title: String
    public let subtitle: String
    public let requestsSystemReviewPrompt: Bool
    public let requestsNotificationPermission: Bool

    public init(
        id: Int,
        imageName: String,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        imageTopOffset: CGFloat,
        title: String,
        subtitle: String,
        requestsSystemReviewPrompt: Bool = false,
        requestsNotificationPermission: Bool = false
    ) {
        precondition(imageWidth > 0, "OnboardingSlide.imageWidth must be > 0")
        precondition(imageHeight > 0, "OnboardingSlide.imageHeight must be > 0")
        precondition(imageTopOffset >= 0, "OnboardingSlide.imageTopOffset must be >= 0")

        self.id = id
        self.imageName = imageName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageTopOffset = imageTopOffset
        self.title = title
        self.subtitle = subtitle
        self.requestsSystemReviewPrompt = requestsSystemReviewPrompt
        self.requestsNotificationPermission = requestsNotificationPermission
    }
}

public struct OnboardingLinks: Equatable {
    public let termsURL: URL
    public let privacyURL: URL

    public init(termsURL: URL, privacyURL: URL) {
        self.termsURL = termsURL
        self.privacyURL = privacyURL
    }
}

public protocol OnboardingContentProviding {
    var slides: [OnboardingSlide] { get }
    var links: OnboardingLinks { get }
}

public struct DefaultOnboardingContentProvider: OnboardingContentProviding {
    public let slides: [OnboardingSlide] = [
        .init(
            id: 0,
            imageName: "Onboarding.1en",
            imageWidth: 375.scale,
            imageHeight: 812.scale,
            imageTopOffset: 0.scale,
            title: "Bring Your Ideas to Life",
            subtitle: "Create stunning AI videos and images from simple text prompts in seconds."
        ),
        .init(
            id: 1,
            imageName: "Onboarding.2en",
            imageWidth: 375.scale,
            imageHeight: 812.scale,
            imageTopOffset: 0.scale,
            title: "Ultra-Realistic AI Voices",
            subtitle: "Turn any text into professional speech. Perfect for videos, podcasts, and more.",
            requestsSystemReviewPrompt: true
        ),
        .init(
            id: 2,
            imageName: "Onboarding.3en",
            imageWidth: 375.scale,
            imageHeight: 812.scale,
            imageTopOffset: 0.scale,
            title: "Effortless Transcriptions",
            subtitle: "Convert audio and video into perfect text and smart summaries.",
            requestsNotificationPermission: true
        )
    ]

    public let links: OnboardingLinks = .init(
        termsURL: AppExternalResources.termsOfUseURL,
        privacyURL: AppExternalResources.privacyPolicyURL
    )

    public init() {}
}
