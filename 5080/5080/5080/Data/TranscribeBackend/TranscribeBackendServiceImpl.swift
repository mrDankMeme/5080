import Foundation

final class TranscribeBackendServiceImpl: TranscribeBackendService {
    private let config: TranscribeAPIConfig
    private let http: HTTPClient

    init(config: TranscribeAPIConfig, http: HTTPClient) {
        self.config = config
        self.http = http
    }

    func transcribe(_ request: TranscribeRequest) async throws -> BackendTranscribeResult {
        let startData = try await startTranscription(request)
        return try await transcriptionResult(taskId: startData.taskId)
    }

    func startTranscription(_ request: TranscribeRequest) async throws -> BackendTranscribeStartData {
        let normalizedRequest = try await parseRequest(
            from: request.payloadData,
            localFile: request.localFile
        )
        let taskID = try await startProcessing(normalizedRequest)
        return BackendTranscribeStartData(taskId: taskID)
    }

    func transcriptionResult(taskId: String) async throws -> BackendTranscribeResult {
        let finalStatus = try await waitForCompletion(taskID: taskId)
        let resultData = try await fetchResult(taskID: taskId)

        return BackendTranscribeResult(
            taskId: taskId,
            status: finalStatus,
            resultJSONString: Self.prettyString(from: resultData),
            rawResultData: resultData
        )
    }
}

private extension TranscribeBackendServiceImpl {
    func parseRequest(from payloadData: Data, localFile: BinaryUpload?) async throws -> NormalizedTranscribeRequest {
        let rawObject = try JSONSerialization.jsonObject(with: payloadData)
        guard let dictionary = rawObject as? [String: Any] else {
            throw APIError.backendMessage("Transcribe payload must be a JSON object")
        }

        let isVideo = Self.readBool(from: dictionary, keys: ["is_video", "isVideo"]) ?? false

        var fields: [String: String] = [
            "is_video": isVideo ? "true" : "false"
        ]

        if let deviceID = Self.readString(from: dictionary, keys: ["device_id", "deviceId", "userId"]) {
            fields["device_id"] = deviceID
        }

        if let localFile, !localFile.data.isEmpty {
            let normalizedMime = localFile.mimeType.lowercased()
            if normalizedMime.hasPrefix("audio") {
                fields["is_video"] = "false"
            } else if normalizedMime.hasPrefix("video") {
                fields["is_video"] = "true"
            }

            return NormalizedTranscribeRequest(
                fields: fields,
                fileData: localFile.data,
                fileName: localFile.fileName,
                mimeType: localFile.mimeType
            )
        }

        if let base64File = Self.readString(from: dictionary, keys: ["fileBase64", "mediaBase64", "file"]) {
            if let decoded = Self.decodeBase64Payload(base64File) {
                return NormalizedTranscribeRequest(
                    fields: fields,
                    fileData: decoded.data,
                    fileName: decoded.fileName,
                    mimeType: decoded.mimeType
                )
            }
        }

        guard let remoteURLString = Self.resolveMediaURLString(from: dictionary, isVideo: isVideo),
              let remoteURL = URL(string: remoteURLString) else {
            throw APIError.backendMessage("Transcribe payload requires local file, fileUrl/mediaUrl, or fileBase64")
        }

        let mediaData = try await http.sendData(
            HTTPRequest(url: remoteURL, method: .get)
        )

        guard !mediaData.isEmpty else {
            throw APIError.backendMessage("Downloaded media file is empty")
        }

        let fileName = Self.fileName(from: remoteURL, isVideo: isVideo)
        let mimeType = Self.mimeType(from: remoteURL.pathExtension, isVideo: isVideo)

        return NormalizedTranscribeRequest(
            fields: fields,
            fileData: mediaData,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func startProcessing(_ request: NormalizedTranscribeRequest) async throws -> String {
        let endpoint = TranscribeBackendEndpoint.transcribing.url(baseURL: config.baseURL)
        let builder = MultipartFormDataBuilder()

        let files = [
            MultipartFormDataBuilder.File(
                name: "file",
                filename: request.fileName,
                mimeType: request.mimeType,
                data: request.fileData
            )
        ]

        let httpRequest = HTTPRequest(
            url: endpoint,
            method: .post,
            headers: headers(contentType: builder.contentTypeHeaderValue()),
            body: builder.buildBody(fields: request.fields, files: files)
        )

        let data = try await http.sendData(httpRequest)
        return try Self.extractTaskID(from: data)
    }

    func waitForCompletion(taskID: String) async throws -> String {
        var lastStatus = "started"

        for _ in 1...TranscribeBackendDefaults.maxPollingAttempts {
            let endpoint = TranscribeBackendEndpoint.status(taskID: taskID).url(baseURL: config.baseURL)
            let request = HTTPRequest(
                url: endpoint,
                method: .get,
                headers: headers()
            )

            let data = try await http.sendData(request)
            let status = try Self.extractStatus(from: data)
            lastStatus = status

            if Self.isCompletedStatus(status) {
                return status
            }

            if Self.isFailureStatus(status) {
                let message = Self.extractMessage(from: data) ?? "Transcribe task failed"
                throw APIError.backendMessage("\(message) (status=\(status), taskId=\(taskID))")
            }

            try await Task.sleep(nanoseconds: TranscribeBackendDefaults.pollingIntervalNanoseconds)
        }

        throw APIError.backendMessage("Transcribe polling timeout (taskId=\(taskID), lastStatus=\(lastStatus))")
    }

    func fetchResult(taskID: String) async throws -> Data {
        let endpoint = TranscribeBackendEndpoint.result(taskID: taskID).url(baseURL: config.baseURL)
        let request = HTTPRequest(
            url: endpoint,
            method: .get,
            headers: headers()
        )

        return try await http.sendData(request)
    }

    func headers(contentType: String? = nil) -> [String: String] {
        var result: [String: String] = [
            "X-Api-Key": config.apiKey,
            "Accept": "application/json"
        ]

        if let contentType {
            result["Content-Type"] = contentType
        }

        return result
    }
}

private extension TranscribeBackendServiceImpl {
    static func readString(from dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let rawValue = dictionary[key] {
                let value = String(describing: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    static func readBool(from dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            guard let rawValue = dictionary[key] else { continue }

            if let boolValue = rawValue as? Bool {
                return boolValue
            }

            if let intValue = rawValue as? Int {
                return intValue != 0
            }

            let normalized = String(describing: rawValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch normalized {
            case "true", "1", "yes", "y", "on":
                return true
            case "false", "0", "no", "n", "off":
                return false
            default:
                continue
            }
        }

        return nil
    }

    static func resolveMediaURLString(from dictionary: [String: Any], isVideo: Bool) -> String? {
        let topLevelCandidates: [String]
        if isVideo {
            topLevelCandidates = ["fileUrl", "mediaUrl", "videoUrl", "url", "audioUrl"]
        } else {
            topLevelCandidates = ["fileUrl", "mediaUrl", "audioUrl", "url", "videoUrl"]
        }

        if let topLevelURL = readString(from: dictionary, keys: topLevelCandidates) {
            return topLevelURL
        }

        guard let items = dictionary["items"] as? [[String: Any]],
              let firstItem = items.first else {
            return nil
        }

        if isVideo {
            return readString(from: firstItem, keys: ["videoUrl", "audioUrl", "url", "fileUrl", "mediaUrl"])
        }

        return readString(from: firstItem, keys: ["audioUrl", "videoUrl", "url", "fileUrl", "mediaUrl"])
    }

    static func decodeBase64Payload(_ rawValue: String) -> (data: Data, fileName: String, mimeType: String)? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var mimeType = "application/octet-stream"
        var fileName = "media.bin"
        var base64Part = trimmed

        if trimmed.hasPrefix("data:"),
           let commaIndex = trimmed.firstIndex(of: ",") {
            let prefix = String(trimmed[..<commaIndex])
            base64Part = String(trimmed[trimmed.index(after: commaIndex)...])

            if prefix.contains("audio/wav") {
                mimeType = "audio/wav"
                fileName = "audio.wav"
            } else if prefix.contains("audio/mpeg") {
                mimeType = "audio/mpeg"
                fileName = "audio.mp3"
            } else if prefix.contains("video/mp4") {
                mimeType = "video/mp4"
                fileName = "video.mp4"
            }
        }

        guard let data = Data(base64Encoded: base64Part, options: [.ignoreUnknownCharacters]), !data.isEmpty else {
            return nil
        }

        return (data: data, fileName: fileName, mimeType: mimeType)
    }

    static func fileName(from url: URL, isVideo: Bool) -> String {
        let candidate = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.isEmpty {
            return candidate
        }
        return isVideo ? "transcribe.mp4" : "transcribe.wav"
    }

    static func mimeType(from pathExtension: String, isVideo: Bool) -> String {
        switch pathExtension.lowercased() {
        case "mp4", "mov", "m4v", "webm":
            return "video/mp4"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "aac":
            return "audio/aac"
        case "ogg":
            return "audio/ogg"
        default:
            return isVideo ? "video/mp4" : "audio/wav"
        }
    }

    static func extractTaskID(from data: Data) throws -> String {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let taskID = lookupString(in: jsonObject, for: ["task_id", "taskId", "id"]),
              !taskID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.backendMessage("Transcribe backend did not return task_id")
        }

        return taskID
    }

    static func extractStatus(from data: Data) throws -> String {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let status = lookupString(in: jsonObject, for: ["status", "state"]),
              !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.backendMessage("Transcribe backend did not return status")
        }

        return status
    }

    static func extractMessage(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return lookupString(in: jsonObject, for: ["message", "error", "detail", "reason"])
    }

    static func isCompletedStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["COMPLETED", "SUCCESS", "DONE"].contains(normalized)
    }

    static func isFailureStatus(_ status: String) -> Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["FAILURE", "FAILED", "ERROR", "CANCELLED", "CANCELED"].contains(normalized)
    }

    static func prettyString(from data: Data) -> String {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(jsonObject),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        if let utfString = String(data: data, encoding: .utf8),
           !utfString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return utfString
        }

        return "<binary payload \(data.count) bytes>"
    }

    static func lookupString(in jsonObject: Any, for keys: [String]) -> String? {
        if let dictionary = jsonObject as? [String: Any] {
            for key in keys {
                if let value = dictionary[key] {
                    if let stringValue = value as? String {
                        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            return trimmed
                        }
                    } else if let intValue = value as? Int {
                        return String(intValue)
                    } else if let doubleValue = value as? Double {
                        return String(doubleValue)
                    }
                }
            }

            for value in dictionary.values {
                if let nestedValue = lookupString(in: value, for: keys) {
                    return nestedValue
                }
            }
        }

        if let array = jsonObject as? [Any] {
            for value in array {
                if let nestedValue = lookupString(in: value, for: keys) {
                    return nestedValue
                }
            }
        }

        return nil
    }
}

private extension TranscribeBackendServiceImpl {
    struct NormalizedTranscribeRequest {
        let fields: [String: String]
        let fileData: Data
        let fileName: String
        let mimeType: String
    }
}
