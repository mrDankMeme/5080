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

    func fetchCurrentUser() async throws -> SiteMakerCurrentUser {
        try await performAuthorizedRequest { context in
            try await remoteService.fetchCurrentUser(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken
            )
        }
    }

    func listProjects() async throws -> [SiteMakerProjectSummary] {
        try await performAuthorizedRequest { context in
            try await remoteService.listProjects(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken
            )
        }
    }

    func createProject(prompt: String) async throws -> SiteMakerProject {
        try await performAuthorizedRequest { context in
            try await remoteService.createProject(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                prompt: prompt
            )
        }
    }

    func fetchProject(id: String) async throws -> SiteMakerProject {
        try await performAuthorizedRequest { context in
            try await remoteService.fetchProject(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                projectID: id
            )
        }
    }

    func uploadAsset(
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset {
        try await performAuthorizedRequest { context in
            try await remoteService.uploadAsset(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                projectID: projectID,
                projectSlug: projectSlug,
                payload: payload
            )
        }
    }

    func streamClarify(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await performAuthorizedRequest { context in
            try await remoteService.streamClarify(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                projectID: projectID,
                prompt: prompt,
                onEvent: onEvent
            )
        }
    }

    func streamGenerate(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await performAuthorizedRequest { context in
            try await remoteService.streamGenerate(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                projectID: projectID,
                prompt: prompt,
                onEvent: onEvent
            )
        }
    }

    func streamEdit(
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws {
        try await performAuthorizedRequest { context in
            try await remoteService.streamEdit(
                baseURLString: context.baseURLString,
                accessToken: context.accessToken,
                projectID: projectID,
                instruction: instruction,
                onEvent: onEvent
            )
        }
    }
}

private extension DefaultSiteMakerRepository {
    func performAuthorizedRequest<T>(
        _ operation: (SiteMakerAuthorizedContext) async throws -> T
    ) async throws -> T {
        let context = try await authorizationProvider.authorizedContext()

        do {
            return try await operation(context)
        } catch let error as SiteMakerBuilderError where error.isUnauthorized {
            let refreshedContext = try await authorizationProvider.authorizedContext()
            return try await operation(refreshedContext)
        }
    }
}

private extension SiteMakerBuilderError {
    var isUnauthorized: Bool {
        guard case .backend(let statusCode, _) = self else {
            return false
        }

        return statusCode == 401 || statusCode == 403
    }
}
