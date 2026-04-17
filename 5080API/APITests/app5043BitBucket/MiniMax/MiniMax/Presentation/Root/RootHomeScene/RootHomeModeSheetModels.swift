import Foundation

struct RootHomeModeSection: Identifiable, Hashable {
    let id: String
    let title: String
    let primaryOption: RootHomeModeOption?
    let secondaryOptions: [RootHomeModeOption]
}

struct RootHomeModeOption: Identifiable, Hashable {
    let id: String
    let title: String
    let iconAssetName: String

    var flowKind: HistoryFlowKind {
        switch id {
        case RootHomeModeOptionID.textToVideo:
            return .textToVideo
        case RootHomeModeOptionID.animateImage:
            return .animateImage
        case RootHomeModeOptionID.frameToVideo:
            return .frameToVideo
        case RootHomeModeOptionID.voiceGen:
            return .voiceGen
        case RootHomeModeOptionID.transcribe:
            return .transcribe
        case RootHomeModeOptionID.aiImage:
            return .aiImage
        default:
            return .textToVideo
        }
    }

    var isTextToVideo: Bool {
        id == RootHomeModeOptionID.textToVideo
    }

    var isAnimateImage: Bool {
        id == RootHomeModeOptionID.animateImage
    }

    var isFrameToVideo: Bool {
        id == RootHomeModeOptionID.frameToVideo
    }

    var isVoiceGen: Bool {
        id == RootHomeModeOptionID.voiceGen
    }

    var isTranscribe: Bool {
        id == RootHomeModeOptionID.transcribe
    }

    var isAIImage: Bool {
        id == RootHomeModeOptionID.aiImage
    }
}

enum RootHomeModeOptionID {
    static let textToVideo = "text_to_video"
    static let animateImage = "animate_image"
    static let frameToVideo = "frame_to_video"
    static let voiceGen = "voice_gen"
    static let transcribe = "transcribe"
    static let aiImage = "ai_image"
}
