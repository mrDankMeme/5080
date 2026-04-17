import Foundation

struct TranscribeRequest: Sendable {
    let payloadData: Data
    let localFile: BinaryUpload?

    init(payloadData: Data, localFile: BinaryUpload? = nil) {
        self.payloadData = payloadData
        self.localFile = localFile
    }
}

struct BackendTranscribeResult: Sendable {
    let taskId: String
    let status: String
    let resultJSONString: String
    let rawResultData: Data
}

struct BackendTranscribeStartData: Sendable {
    let taskId: String
}

protocol TranscribeBackendService: Sendable {
    func transcribe(_ request: TranscribeRequest) async throws -> BackendTranscribeResult
    func startTranscription(_ request: TranscribeRequest) async throws -> BackendTranscribeStartData
    func transcriptionResult(taskId: String) async throws -> BackendTranscribeResult
}
