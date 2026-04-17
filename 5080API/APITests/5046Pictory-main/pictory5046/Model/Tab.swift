import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case home
    case enhancer
    case video
    case templates
    case history
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .enhancer: return "Enhancer"
        case .video: return "Video"
        case .templates: return "Templates"
        case .history: return "History"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .enhancer: return "lasso.and.sparkles"
        case .video: return "video"
        case .templates: return "rectangle.stack.person.crop"
        case .history: return "clock"
        }
    }
}
