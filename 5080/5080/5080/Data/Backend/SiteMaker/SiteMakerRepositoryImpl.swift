import Foundation

final class DefaultSiteMakerRepository: SiteMakerRepositoryProtocol {
    private let authorizationProvider: SiteMakerAuthorizationProviding
    private let remoteService: SiteMakerRemoteServicing

    init(
        authorizationProvider: SiteMakerAuthorizationProviding,
        remoteService: SiteMakerRemoteServicing
    ) {
        self.authorizationProvider = authorizationProvider
        self.remoteService = remoteService
    }

    func listProjects() async throws -> [SiteMakerProjectSummary] {
        let context = try await authorizationProvider.authorizedContext()
        return try await remoteService.listProjects(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken
        )
    }

    func createProject(prompt: String) async throws -> SiteMakerProject {
        let context = try await authorizationProvider.authorizedContext()
        return try await remoteService.createProject(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            prompt: prompt
        )
    }

    func fetchProject(id: String) async throws -> SiteMakerProject {
        let context = try await authorizationProvider.authorizedContext()
        return try await remoteService.fetchProject(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            projectID: id
        )
    }

    func uploadAsset(
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset {
        let context = try await authorizationProvider.authorizedContext()
        return try await remoteService.uploadAsset(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            projectID: projectID,
            projectSlug: projectSlug,
            payload: payload
        )
    }

    func streamClarify(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        let context = try await authorizationProvider.authorizedContext()
        try await remoteService.streamClarify(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            projectID: projectID,
            prompt: prompt,
            onEvent: onEvent
        )
    }

    func streamGenerate(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        let context = try await authorizationProvider.authorizedContext()
        try await remoteService.streamGenerate(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            projectID: projectID,
            prompt: prompt,
            onEvent: onEvent
        )
    }

    func streamEdit(
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        let context = try await authorizationProvider.authorizedContext()
        try await remoteService.streamEdit(
            baseURLString: context.baseURLString,
            accessToken: context.accessToken,
            projectID: projectID,
            instruction: instruction,
            onEvent: onEvent
        )
    }
}
