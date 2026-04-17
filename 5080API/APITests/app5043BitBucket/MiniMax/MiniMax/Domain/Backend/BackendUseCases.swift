import Foundation

protocol AuthorizeUserUseCase {
    func execute(userId: String, gender: String) async throws -> BackendAuthData
}

struct DefaultAuthorizeUserUseCase: AuthorizeUserUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String, gender: String = "m") async throws -> BackendAuthData {
        try await service.authorize(userId: userId, gender: gender)
    }
}

protocol FetchProfileUseCase {
    func execute(userId: String) async throws -> BackendProfileData
}

struct DefaultFetchProfileUseCase: FetchProfileUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String) async throws -> BackendProfileData {
        try await service.fetchProfile(userId: userId)
    }
}

protocol SetFreeGenerationsUseCase {
    func execute(userId: String) async throws
}

struct DefaultSetFreeGenerationsUseCase: SetFreeGenerationsUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String) async throws {
        try await service.setFreeGenerations(userId: userId)
    }
}

protocol AddGenerationsUseCase {
    func execute(userId: String, productId: Int) async throws
}

struct DefaultAddGenerationsUseCase: AddGenerationsUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String, productId: Int) async throws {
        try await service.addGenerations(userId: userId, productId: productId)
    }
}

protocol CollectTokensUseCase {
    func execute(userId: String) async throws
}

struct DefaultCollectTokensUseCase: CollectTokensUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String) async throws {
        try await service.collectTokens(userId: userId)
    }
}

protocol FetchAvailableBonusesUseCase {
    func execute(userId: String) async throws -> [BackendAvailableBonusItem]
}

struct DefaultFetchAvailableBonusesUseCase: FetchAvailableBonusesUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String) async throws -> [BackendAvailableBonusItem] {
        try await service.fetchAvailableBonuses(userId: userId)
    }
}

protocol FetchServicePricesUseCase {
    func execute(userId: String) async throws -> BackendServicePricesData
}

struct DefaultFetchServicePricesUseCase: FetchServicePricesUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String) async throws -> BackendServicePricesData {
        try await service.fetchServicePrices(userId: userId)
    }
}

protocol GenerateTextToVideoUseCase {
    func execute(_ request: TextToVideoRequest) async throws -> BackendGenerationStartData
}

struct DefaultGenerateTextToVideoUseCase: GenerateTextToVideoUseCase {
    let service: MiniMaxBackendService

    func execute(_ request: TextToVideoRequest) async throws -> BackendGenerationStartData {
        try await service.textToVideo(request)
    }
}

protocol AnimateImageUseCase {
    func execute(_ request: AnimateImageRequest) async throws -> BackendGenerationStartData
}

struct DefaultAnimateImageUseCase: AnimateImageUseCase {
    let service: MiniMaxBackendService

    func execute(_ request: AnimateImageRequest) async throws -> BackendGenerationStartData {
        try await service.animateImage(request)
    }
}

protocol FrameToVideoUseCase {
    func execute(_ request: FrameToVideoRequest) async throws -> BackendGenerationStartData
}

struct DefaultFrameToVideoUseCase: FrameToVideoUseCase {
    let service: MiniMaxBackendService

    func execute(_ request: FrameToVideoRequest) async throws -> BackendGenerationStartData {
        try await service.frameToVideo(request)
    }
}

protocol VoiceGenUseCase {
    func execute(_ request: VoiceGenRequest) async throws -> BackendGenerationStartData
}

struct DefaultVoiceGenUseCase: VoiceGenUseCase {
    let service: MiniMaxBackendService

    func execute(_ request: VoiceGenRequest) async throws -> BackendGenerationStartData {
        try await service.generateVoice(request)
    }
}

protocol GenerateAIImageUseCase {
    func execute(_ request: AIImageRequest) async throws -> BackendGenerationStartData
}

struct DefaultGenerateAIImageUseCase: GenerateAIImageUseCase {
    let service: MiniMaxBackendService

    func execute(_ request: AIImageRequest) async throws -> BackendGenerationStartData {
        try await service.generateAIImage(request)
    }
}

protocol GenerationStatusUseCase {
    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload
}

struct DefaultGenerationStatusUseCase: GenerationStatusUseCase {
    let service: MiniMaxBackendService

    func execute(userId: String, jobId: String) async throws -> BackendGenerationStatusPayload {
        try await service.generationStatus(userId: userId, jobId: jobId)
    }
}
