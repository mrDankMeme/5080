import AVFoundation
import Foundation

enum TranscribeRecoveryMediaStore {
    static func persist(_ media: TranscribeSelectedMedia) throws -> String {
        let fileManager = FileManager.default
        let directoryURL = try storageDirectoryURL(fileManager: fileManager)
        let fileExtension = resolvedFileExtension(for: media)
        let fileName = "transcribe_media_\(UUID().uuidString).\(fileExtension)"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try media.data.write(to: fileURL, options: .atomic)
        return fileName
    }

    static func load(
        persistedFileName: String,
        originalFileName: String,
        mimeType: String,
        isVideo: Bool
    ) throws -> TranscribeSelectedMedia {
        let fileManager = FileManager.default
        let directoryURL = try storageDirectoryURL(fileManager: fileManager)
        let fileURL = directoryURL.appendingPathComponent(persistedFileName)
        let data = try Data(contentsOf: fileURL)

        return TranscribeSelectedMedia(
            data: data,
            fileName: originalFileName,
            mimeType: mimeType,
            isVideo: isVideo
        )
    }

    static func remove(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        let fileManager = FileManager.default
        guard let directoryURL = try? storageDirectoryURL(fileManager: fileManager) else { return }
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    private static func storageDirectoryURL(fileManager: FileManager) throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let directoryURL = appSupport
            .appendingPathComponent("History", isDirectory: true)
            .appendingPathComponent("PendingTranscribeMedia", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func resolvedFileExtension(for media: TranscribeSelectedMedia) -> String {
        let existingExtension = NSString(string: media.fileName)
            .pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !existingExtension.isEmpty {
            return existingExtension
        }

        let normalizedMimeType = media.mimeType.lowercased()
        if normalizedMimeType.contains("video") {
            return "mp4"
        }
        if normalizedMimeType.contains("wav") {
            return "wav"
        }
        if normalizedMimeType.contains("mpeg") || normalizedMimeType.contains("mp3") {
            return "mp3"
        }
        if normalizedMimeType.contains("mp4") || normalizedMimeType.contains("m4a") {
            return "m4a"
        }

        return media.isVideo ? "mp4" : "mp3"
    }
}

enum TranscribeUploadBuilder {
    static func makeBinaryUpload(from media: TranscribeSelectedMedia) async throws -> BinaryUpload {
        if media.isVideo {
            return try await extractAudioBinaryUpload(from: media)
        }

        return makeAudioUpload(from: media)
    }

    private static func makeAudioUpload(from media: TranscribeSelectedMedia) -> BinaryUpload {
        let fileName = normalizedAudioFileName(from: media.fileName)
        let mimeType = media.mimeType.isEmpty ? "audio/mpeg" : media.mimeType
        return BinaryUpload(data: media.data, fileName: fileName, mimeType: mimeType)
    }

    private static func extractAudioBinaryUpload(from media: TranscribeSelectedMedia) async throws -> BinaryUpload {
        let extracted = try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let temporaryFolder = fileManager.temporaryDirectory.appendingPathComponent("TranscribeTemp", isDirectory: true)
            try fileManager.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)

            let inputURL = temporaryFolder.appendingPathComponent("input_\(UUID().uuidString).mp4")
            let outputURL = temporaryFolder.appendingPathComponent("output_\(UUID().uuidString).m4a")

            try media.data.write(to: inputURL, options: .atomic)
            defer {
                try? fileManager.removeItem(at: inputURL)
            }

            let asset = AVURLAsset(url: inputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw APIError.backendMessage("Unable to prepare video audio extraction")
            }

            if fileManager.fileExists(atPath: outputURL.path) {
                try? fileManager.removeItem(at: outputURL)
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            exportSession.shouldOptimizeForNetworkUse = true

            try await exportSession.export(to: outputURL, as: .m4a)

            defer {
                try? fileManager.removeItem(at: outputURL)
            }

            let extractedAudioData = try Data(contentsOf: outputURL)
            guard !extractedAudioData.isEmpty else {
                throw APIError.backendMessage("Extracted audio is empty")
            }

            let baseName = NSString(string: media.fileName).deletingPathExtension
            let normalizedBase = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let audioFileName = (normalizedBase.isEmpty ? "transcribe_audio" : normalizedBase) + ".m4a"

            return (extractedAudioData, audioFileName, "audio/mp4")
        }.value

        return BinaryUpload(
            data: extracted.0,
            fileName: extracted.1,
            mimeType: extracted.2
        )
    }

    private static func normalizedAudioFileName(from original: String) -> String {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "transcribe_audio.mp3"
        }

        let extensionValue = NSString(string: trimmed).pathExtension
        if extensionValue.isEmpty {
            return trimmed + ".mp3"
        }

        return trimmed
    }
}
