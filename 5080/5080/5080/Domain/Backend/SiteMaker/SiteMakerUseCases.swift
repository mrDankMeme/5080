import Foundation

protocol FetchSiteMakerCurrentUserUseCaseProtocol {
    func execute() async throws -> SiteMakerCurrentUser
}

struct DefaultFetchSiteMakerCurrentUserUseCase: FetchSiteMakerCurrentUserUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute() async throws -> SiteMakerCurrentUser {
        try await repository.fetchCurrentUser()
    }
}

protocol FetchSiteMakerProjectsUseCaseProtocol {
    func execute() async throws -> [SiteMakerProjectSummary]
}

struct DefaultFetchSiteMakerProjectsUseCase: FetchSiteMakerProjectsUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute() async throws -> [SiteMakerProjectSummary] {
        try await repository.listProjects()
    }
}

protocol CreateSiteMakerProjectUseCaseProtocol {
    func execute(prompt: String) async throws -> SiteMakerProject
}

struct DefaultCreateSiteMakerProjectUseCase: CreateSiteMakerProjectUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(prompt: String) async throws -> SiteMakerProject {
        try await repository.createProject(prompt: prompt)
    }
}

protocol FetchSiteMakerProjectUseCaseProtocol {
    func execute(id: String) async throws -> SiteMakerProject
}

struct DefaultFetchSiteMakerProjectUseCase: FetchSiteMakerProjectUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(id: String) async throws -> SiteMakerProject {
        try await repository.fetchProject(id: id)
    }
}

protocol UploadSiteMakerAssetUseCaseProtocol {
    func execute(
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset
}

struct DefaultUploadSiteMakerAssetUseCase: UploadSiteMakerAssetUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset {
        try await repository.uploadAsset(
            projectID: projectID,
            projectSlug: projectSlug,
            payload: payload
        )
    }
}

protocol ClarifySiteMakerProjectUseCaseProtocol {
    func execute(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
}

struct DefaultClarifySiteMakerProjectUseCase: ClarifySiteMakerProjectUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await repository.streamClarify(
            projectID: projectID,
            prompt: prompt,
            onEvent: onEvent
        )
    }
}

protocol GenerateSiteMakerProjectUseCaseProtocol {
    func execute(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
}

struct DefaultGenerateSiteMakerProjectUseCase: GenerateSiteMakerProjectUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await repository.streamGenerate(
            projectID: projectID,
            prompt: prompt,
            onEvent: onEvent
        )
    }
}

protocol EditSiteMakerProjectUseCaseProtocol {
    func execute(
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
}

struct DefaultEditSiteMakerProjectUseCase: EditSiteMakerProjectUseCaseProtocol {
    let repository: SiteMakerRepositoryProtocol

    func execute(
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await repository.streamEdit(
            projectID: projectID,
            instruction: instruction,
            onEvent: onEvent
        )
    }
}
