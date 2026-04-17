import Foundation
import Combine

@MainActor
final class TextToVideoLoadingSceneViewModel: ObservableObject {
    let title: String
    let heading: String
    let subtitle: String

    init(
        title: String = "Text to Video",
        heading: String = "Bringing your idea to life...",
        subtitle: String = "Please wait, it won't take long"
    ) {
        self.title = title
        self.heading = heading
        self.subtitle = subtitle
    }
}
