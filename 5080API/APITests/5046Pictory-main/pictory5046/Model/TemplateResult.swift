import Foundation
import SwiftData
import UIKit

enum TemplateResultStatus: String {
    case pending = "PENDING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

@Model
final class TemplateResult {
    var id: UUID
    var jobId: String
    @Attribute(.externalStorage) var inputPhotoData: Data?
    @Attribute(.externalStorage) var inputPhotoSecondData: Data?
    @Attribute(.externalStorage) var resultImageData: Data?
    var generationTypeRaw: String?
    var isVideoResult: Bool
    var resultVideoLocalPath: String?
    var effectStyleId: Int
    var effectId: Int
    var templateTitle: String?
    var requestUserId: String?
    var requestPrompt: String?
    var requestRatioRaw: String?
    var requestStyleId: Int?
    var requestTemplateId: Int?
    var generationStatusRaw: String?
    var generationErrorMessage: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        jobId: String,
        inputPhotoData: Data?,
        inputPhotoSecondData: Data? = nil,
        resultImageData: Data?,
        generationTypeRaw: String? = nil,
        isVideoResult: Bool = false,
        resultVideoLocalPath: String? = nil,
        effectStyleId: Int,
        effectId: Int,
        templateTitle: String?,
        requestUserId: String? = nil,
        requestPrompt: String? = nil,
        requestRatioRaw: String? = nil,
        requestStyleId: Int? = nil,
        requestTemplateId: Int? = nil,
        generationStatusRaw: String? = TemplateResultStatus.pending.rawValue,
        generationErrorMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.jobId = jobId
        self.inputPhotoData = inputPhotoData
        self.inputPhotoSecondData = inputPhotoSecondData
        self.resultImageData = resultImageData
        self.generationTypeRaw = generationTypeRaw
        self.isVideoResult = isVideoResult
        self.resultVideoLocalPath = resultVideoLocalPath
        self.effectStyleId = effectStyleId
        self.effectId = effectId
        self.templateTitle = templateTitle
        self.requestUserId = requestUserId
        self.requestPrompt = requestPrompt
        self.requestRatioRaw = requestRatioRaw
        self.requestStyleId = requestStyleId
        self.requestTemplateId = requestTemplateId
        self.generationStatusRaw = generationStatusRaw
        self.generationErrorMessage = generationErrorMessage
        self.createdAt = createdAt
    }
    
    var resultImage: UIImage? {
        guard let data = resultImageData else { return nil }
        return UIImage(data: data)
    }
    
    var inputImage: UIImage? {
        guard let data = inputPhotoData else { return nil }
        return UIImage(data: data)
    }
    
    var resultVideoURL: URL? {
        guard let resultVideoLocalPath, !resultVideoLocalPath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: resultVideoLocalPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private var isLegacyCompleted: Bool {
        if isVideoResult {
            return resultVideoURL != nil
        }
        return resultImageData != nil
    }

    var status: TemplateResultStatus {
        if let raw = generationStatusRaw,
           let parsed = TemplateResultStatus(rawValue: raw) {
            return parsed
        }
        return isLegacyCompleted ? .completed : .pending
    }
    
    var isCompleted: Bool {
        status == .completed || isLegacyCompleted
    }

    var isFailed: Bool {
        status == .failed
    }

    var isPending: Bool {
        !isCompleted && !isFailed
    }
}
