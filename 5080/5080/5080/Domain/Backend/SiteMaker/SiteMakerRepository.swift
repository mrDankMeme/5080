import Foundation

protocol SiteMakerRepositoryProtocol {
    func listProjects() async throws -> [SiteMakerProjectSummary]
    func createProject(prompt: String) async throws -> SiteMakerProject
    func fetchProject(id: String) async throws -> SiteMakerProject
    func uploadAsset(
        projectID: String,
        projectSlug: String,
        payload: SiteMakerAttachmentUploadPayload
    ) async throws -> SiteMakerUploadedAsset
    func streamClarify(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
    func streamGenerate(
        projectID: String,
        prompt: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
    func streamEdit(
        projectID: String,
        instruction: String,
        onEvent: @escaping @MainActor (SiteMakerStreamEvent) -> Void
    ) async throws
}
