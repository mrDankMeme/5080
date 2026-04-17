import SwiftUI

enum VideoGenerationOption: CaseIterable, Identifiable {
    case promptToVideo
    case photoToAnimation
    case photosToStoryVideo

    var id: Self { self }

    var title: String {
        switch self {
        case .promptToVideo: return "Text"
        case .photoToAnimation: return "Text & Photo"
        case .photosToStoryVideo: return "Text & 2 Photos"
        }
    }
    
    var description: String {
        switch self {
        case .promptToVideo: return "Text to video"
        case .photoToAnimation: return "Text & Photo to video"
        case .photosToStoryVideo: return "Text & 2 Photos to video"
        }
    }
}
