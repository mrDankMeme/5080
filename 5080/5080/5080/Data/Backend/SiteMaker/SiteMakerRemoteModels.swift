import Foundation

struct SiteMakerCurrentUserResponse: Decodable {
    let id: String
    let email: String
    let display_name: String?
    let credits: Int
    let created_at: String

    func toDomain() -> SiteMakerCurrentUser {
        SiteMakerCurrentUser(
            id: id,
            email: email,
            displayName: display_name,
            credits: credits,
            createdAt: created_at
        )
    }
}

struct SiteMakerProjectSummaryResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let status: String
    let preview_url: String?
    let created_at: String
    let updated_at: String

    func toDomain() -> SiteMakerProjectSummary {
        SiteMakerProjectSummary(
            id: id,
            name: name,
            slug: slug,
            status: status,
            previewURLString: preview_url,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

struct SiteMakerProjectResponse: Decodable {
    let id: String
    let user_id: String
    let name: String
    let slug: String
    let description: String?
    let site_type: String
    let status: String
    let preview_url: String?
    let current_spec: String?
    let current_files: String?
    let created_at: String
    let updated_at: String

    func toDomain() -> SiteMakerProject {
        SiteMakerProject(
            id: id,
            userID: user_id,
            name: name,
            slug: slug,
            description: description,
            siteType: site_type,
            status: status,
            previewURLString: preview_url,
            currentSpec: current_spec,
            currentFiles: current_files,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

struct SiteMakerUploadedAssetResponse: Decodable {
    let id: String
    let filename: String
    let content_type: String
    let file_size: Int
    let created_at: String

    func toDomain(
        baseURLString: String,
        projectSlug: String
    ) -> SiteMakerUploadedAsset {
        SiteMakerUploadedAsset(
            id: id,
            fileName: filename,
            mimeType: content_type,
            fileSize: file_size,
            createdAt: created_at,
            publicURLString: publicURLString(
                baseURLString: baseURLString,
                projectSlug: projectSlug
            )
        )
    }

    private func publicURLString(
        baseURLString: String,
        projectSlug: String
    ) -> String? {
        guard var components = URLComponents(string: baseURLString) else {
            return nil
        }

        var basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.lowercased() == "api" {
            basePath = ""
        }

        let assetPath = ["uploads", projectSlug, filename].joined(separator: "/")
        components.path = basePath.isEmpty
            ? "/" + assetPath
            : "/" + basePath + "/" + assetPath

        return components.url?.absoluteString
    }
}

struct SiteMakerCreateProjectRequest: Encodable {
    let name: String
    let description: String?
}

struct SiteMakerPromptRequest: Encodable {
    let prompt: String
}

struct SiteMakerEditRequest: Encodable {
    let instruction: String
}

struct SiteMakerClarifyResponse: Decodable {
    let description: String
    let suggested_theme: String
    let suggested_palette: String
    let questions: [SiteMakerClarifyQuestionResponse]

    func toDomain() -> SiteMakerClarifyResult {
        SiteMakerClarifyResult(
            description: description,
            suggestedTheme: suggested_theme,
            suggestedPalette: suggested_palette,
            questions: questions.map { $0.toDomain() }
        )
    }
}

struct SiteMakerClarifyQuestionResponse: Decodable {
    let id: String
    let question: String
    let options: [String]
    let `default`: Int

    func toDomain() -> SiteMakerClarifyQuestion {
        SiteMakerClarifyQuestion(
            id: id,
            title: question,
            options: options,
            defaultIndex: `default`
        )
    }
}

struct SiteMakerBuildCompleteResponse: Decodable {
    let preview_url: String
    let build: SiteMakerBuildResultResponse

    func toDomain() -> SiteMakerBuildOutcome {
        SiteMakerBuildOutcome(
            previewURLString: preview_url,
            outputPath: build.output_path,
            isSuccess: build.success
        )
    }
}

struct SiteMakerBuildResultResponse: Decodable {
    let success: Bool
    let output_path: String
}

struct SiteMakerFilesWrittenResponse: Decodable {
    let file_count: Int?
    let files: [String]?
    let changed_files: [String]?
    let duration_ms: Int?
}

struct SiteMakerStreamErrorResponse: Decodable {
    let message: String
}
