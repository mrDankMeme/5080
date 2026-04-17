
import Foundation

enum OnboardingSheet: Identifiable {
    case safari(URL)

    var id: String {
        switch self {
        case .safari(let url):
            return "safari-\(url.absoluteString)"
        }
    }
}
