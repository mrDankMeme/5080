import Foundation
import Combine

@MainActor
final class TextToVideoFailedSceneViewModel: ObservableObject {
    let title: String
    let heading: String
    let subtitle: String
    let actionTitle: String

    init(
        title: String = "Text to Video",
        heading: String = "Generation Failed",
        subtitle: String = "We couldn't create your video. Don't worry, your tokens have not been deducted.",
        actionTitle: String = "Try Again"
    ) {
        self.title = title
        self.heading = heading
        self.subtitle = subtitle
        self.actionTitle = actionTitle
    }
}
