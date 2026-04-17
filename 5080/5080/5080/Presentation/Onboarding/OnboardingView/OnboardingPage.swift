
import Foundation
import CoreGraphics

public struct OnboardingSlideScaleValue: Equatable {
    public let x: CGFloat
    public let y: CGFloat

    public static let identity = OnboardingSlideScaleValue(x: 1, y: 1)

    public init(x: CGFloat = 1, y: CGFloat = 1) {
        precondition(x > 0, "OnboardingSlideScaleValue.x must be > 0")
        precondition(y > 0, "OnboardingSlideScaleValue.y must be > 0")

        self.x = x
        self.y = y
    }
}

public struct OnboardingSlideScale: Equatable {
    public let smallStatusBar: OnboardingSlideScaleValue
    public let notch: OnboardingSlideScaleValue
    public let dynamicIsland: OnboardingSlideScaleValue
    public let iPad: OnboardingSlideScaleValue
    public let unknown: OnboardingSlideScaleValue

    public init(
        x: CGFloat = 1,
        y: CGFloat = 1
    ) {
        let uniformScale = OnboardingSlideScaleValue(x: x, y: y)
        self.init(
            smallStatusBar: uniformScale,
            notch: uniformScale,
            dynamicIsland: uniformScale,
            iPad: uniformScale,
            unknown: uniformScale
        )
    }

    public init(
        smallStatusBar: OnboardingSlideScaleValue = .identity,
        notch: OnboardingSlideScaleValue = .identity,
        dynamicIsland: OnboardingSlideScaleValue = .identity,
        iPad: OnboardingSlideScaleValue = .identity,
        unknown: OnboardingSlideScaleValue = .identity
    ) {
        self.smallStatusBar = smallStatusBar
        self.notch = notch
        self.dynamicIsland = dynamicIsland
        self.iPad = iPad
        self.unknown = unknown
    }

    func resolve(for layoutType: DeviceLayoutType) -> OnboardingSlideScaleValue {
        switch layoutType {
        case .smallStatusBar:
            return smallStatusBar
        case .notch:
            return notch
        case .dynamicIsland:
            return dynamicIsland
        case .iPad:
            return iPad
        case .unknown:
            return unknown
        }
    }
}

public struct OnboardingSlide: Equatable, Identifiable {
    public let id: Int
    public let imageName: String
    public let imageWidth: CGFloat
    public let imageHeight: CGFloat
    public let imageTopOffset: CGFloat
    public let scale: OnboardingSlideScale
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
        scale: OnboardingSlideScale = .init(),
        title: String,
        subtitle: String,
        requestsSystemReviewPrompt: Bool = false,
        requestsNotificationPermission: Bool = false
    ) {
        precondition(imageWidth > 0, "OnboardingSlide.imageWidth must be > 0")
        precondition(imageHeight > 0, "OnboardingSlide.imageHeight must be > 0")
        //precondition(imageTopOffset >= 0, "OnboardingSlide.imageTopOffset must be >= 0")

        self.id = id
        self.imageName = imageName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageTopOffset = imageTopOffset
        self.scale = scale
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
    public let slides: [OnboardingSlide] = Self.makeSlides()
    public let links: OnboardingLinks = .init(
        termsURL: AppExternalResources.termsOfUseURL,
        privacyURL: AppExternalResources.privacyPolicyURL
    )

    public init() {}
}

private extension DefaultOnboardingContentProvider {
    static func makeSlides() -> [OnboardingSlide] {
       

        return [
            .init(
                id: 0,
                imageName: "Onboarding.1en",
                imageWidth: 344.scale,
                imageHeight: 500.scale,
                imageTopOffset: 0.scale,
                scale: .init(x: 1, y: 1),
                title: "Build Websites & Apps in Seconds",
                subtitle: "Turn your ideas into real products — no coding\nneeded"
            ),
            .init(
                id: 1,
                imageName: "Onboarding.2en",
                imageWidth: 370.scale,
                imageHeight: 588.scale,
                imageTopOffset:  -30.scale,
                scale: .init(x: 1, y: 1),
                title: "AI Does the Hard Work",
                subtitle: "Describe what you want, and get a ready-to-use\ndesign and structure instantly",
                requestsSystemReviewPrompt: true
            ),
            .init(
                id: 2,
                imageName: "Onboarding.3en",
                imageWidth: 370.scale,
                imageHeight: 588.scale,
                imageTopOffset: -30.scale,
                scale: .init(x: 1, y: 1),
                title: "Launch Faster Than Ever",
                subtitle: "Edit, customize, and publish your project in just a\nfew taps",
                requestsNotificationPermission: true
            )
        ]
    }
}
