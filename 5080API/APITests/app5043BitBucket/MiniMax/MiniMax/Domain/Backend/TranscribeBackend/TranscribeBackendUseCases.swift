import Foundation

protocol TranscribeUseCase: Sendable {
    func execute(_ request: TranscribeRequest) async throws -> BackendTranscribeResult
    func start(_ request: TranscribeRequest) async throws -> BackendTranscribeStartData
    func resume(taskId: String) async throws -> BackendTranscribeResult
}

struct DefaultTranscribeUseCase: TranscribeUseCase {
    let service: TranscribeBackendService

    func execute(_ request: TranscribeRequest) async throws -> BackendTranscribeResult {
        try await service.transcribe(request)
    }

    func start(_ request: TranscribeRequest) async throws -> BackendTranscribeStartData {
        try await service.startTranscription(request)
    }

    func resume(taskId: String) async throws -> BackendTranscribeResult {
        try await service.transcriptionResult(taskId: taskId)
    }
}
