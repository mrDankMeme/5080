import Foundation

enum MiniMaxBackendEndpoint: Sendable {
    case userLogin
    case userProfile
    case userSetFreeGenerations
    case userAddGenerations
    case userCollectTokens
    case userAvailableBonuses
    case servicesStatus
    case servicesPrices

    case textToVideo
    case animateImage
    case frameToVideo

    case voiceGen
    case aiImage

    var path: String {
        switch self {
        case .userLogin:
            return "user/login"
        case .userProfile:
            return "user/profile"
        case .userSetFreeGenerations:
            return "user/setFreeGenerations"
        case .userAddGenerations:
            return "user/addGenerations"
        case .userCollectTokens:
            return "user/collectTokens"
        case .userAvailableBonuses:
            return "user/availableBonuses"
        case .servicesStatus:
            return "services/status"
        case .servicesPrices:
            return "services/prices"

        case .textToVideo:
            return "video/generate/txt2video"
        case .animateImage:
            return "photo/generate/animation"
        case .frameToVideo:
            return "video/generate/frame"

        case .voiceGen:
            return "clips/minimax15"
        case .aiImage:
            return "photo/generate/txt2img"
        }
    }

    func url(baseURL: URL) -> URL {
        baseURL.appendingPathComponent(path)
    }
}
