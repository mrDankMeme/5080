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

    private enum CodingKeys: String, CodingKey {
        case description
        case suggested_theme
        case suggestedTheme
        case suggested_palette
        case suggestedPalette
        case questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawDescription = (
            try container.decodeIfPresent(String.self, forKey: .description)
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawSuggestedTheme = (
            try container.decodeIfPresent(String.self, forKey: .suggested_theme)
            ?? container.decodeIfPresent(String.self, forKey: .suggestedTheme)
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawSuggestedPalette = (
            try container.decodeIfPresent(String.self, forKey: .suggested_palette)
            ?? container.decodeIfPresent(String.self, forKey: .suggestedPalette)
        )?.trimmingCharacters(in: .whitespacesAndNewlines)

        let decodedQuestions = try container.decodeIfPresent(
            [SiteMakerClarifyQuestionResponse].self,
            forKey: .questions
        )
        let fallbackDecodedQuestions: [SiteMakerClarifyQuestionResponse]? = {
            guard let rawQuestionsJSONString = try? container.decodeIfPresent(
                String.self,
                forKey: .questions
            ) else {
                return nil
            }

            guard let data = rawQuestionsJSONString.data(using: .utf8) else {
                return nil
            }

            return try? JSONDecoder().decode(
                [SiteMakerClarifyQuestionResponse].self,
                from: data
            )
        }()

        self.description = (rawDescription?.isEmpty == false)
            ? rawDescription!
            : "Clarify complete."
        self.suggested_theme = (rawSuggestedTheme?.isEmpty == false)
            ? rawSuggestedTheme!
            : "-"
        self.suggested_palette = (rawSuggestedPalette?.isEmpty == false)
            ? rawSuggestedPalette!
            : "-"
        self.questions = decodedQuestions ?? fallbackDecodedQuestions ?? []
    }

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

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case title
        case prompt
        case options
        case choices
        case `default`
        case default_index
        case defaultIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let parsedID = Self.decodeLossyString(
            from: container,
            keys: [.id]
        ) ?? UUID().uuidString

        let parsedQuestion = Self.decodeLossyString(
            from: container,
            keys: [.question, .title, .prompt]
        ) ?? "Choose an option"

        let parsedOptions = Self.decodeLossyStringArray(
            from: container,
            keys: [.options, .choices]
        )
        let cleanOptions = parsedOptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let resolvedOptions = cleanOptions.isEmpty ? ["Continue"] : cleanOptions

        let rawDefault = Self.decodeLossyInt(
            from: container,
            keys: [.default, .default_index, .defaultIndex]
        ) ?? 0
        let maxDefaultIndex = max(0, resolvedOptions.count - 1)
        let resolvedDefault = min(max(0, rawDefault), maxDefaultIndex)

        self.id = parsedID
        self.question = parsedQuestion
        self.options = resolvedOptions
        self.default = resolvedDefault
    }

    func toDomain() -> SiteMakerClarifyQuestion {
        SiteMakerClarifyQuestion(
            id: id,
            title: question,
            options: options,
            defaultIndex: `default`
        )
    }
}

private extension SiteMakerClarifyQuestionResponse {
    struct OptionObject: Decodable {
        let value: String?

        private enum CodingKeys: String, CodingKey {
            case label
            case title
            case text
            case value
            case name
        }

        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer() {
                if let stringValue = try? container.decode(String.self) {
                    value = stringValue
                    return
                }
                if let intValue = try? container.decode(Int.self) {
                    value = String(intValue)
                    return
                }
                if let doubleValue = try? container.decode(Double.self) {
                    value = String(doubleValue)
                    return
                }
                if let boolValue = try? container.decode(Bool.self) {
                    value = boolValue ? "true" : "false"
                    return
                }
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = Self.decodeLossyString(from: container)
        }

        private static func decodeLossyString(
            from container: KeyedDecodingContainer<CodingKeys>
        ) -> String? {
            for key in [CodingKeys.label, .title, .text, .value, .name] {
                if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
                    return stringValue
                }
                if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                    return String(intValue)
                }
                if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                    return String(doubleValue)
                }
                if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
                    return boolValue ? "true" : "false"
                }
            }

            return nil
        }
    }

    private static func decodeLossyString(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
                return stringValue
            }
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
            if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return boolValue ? "true" : "false"
            }
        }

        return nil
    }

    private static func decodeLossyInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                return intValue
            }
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsedInt = Int(trimmed) {
                    return parsedInt
                }
                if let parsedDouble = Double(trimmed) {
                    return Int(parsedDouble)
                }
            }
            if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Int(doubleValue)
            }
        }

        return nil
    }

    private static func decodeLossyStringArray(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [String] {
        for key in keys {
            if let values = try? container.decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let values = try? container.decodeIfPresent([OptionObject].self, forKey: key) {
                let flattened = values.compactMap(\.value)
                if !flattened.isEmpty {
                    return flattened
                }
            }
            if let singleValue = try? container.decodeIfPresent(String.self, forKey: key) {
                let pieces = singleValue
                    .split(separator: "|")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !pieces.isEmpty {
                    return pieces
                }
            }
        }

        return []
    }
}

struct SiteMakerBuildCompleteResponse: Decodable {
    let preview_url: String
    let build: SiteMakerBuildResultResponse

    private enum CodingKeys: String, CodingKey {
        case preview_url
        case previewUrl
        case build
        case success
        case output_path
        case outputPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeCasePreviewURL = try container.decodeIfPresent(String.self, forKey: .preview_url)
        let camelCasePreviewURL = try container.decodeIfPresent(String.self, forKey: .previewUrl)

        self.preview_url = snakeCasePreviewURL ?? camelCasePreviewURL ?? ""

        if let nestedBuild = try container.decodeIfPresent(
            SiteMakerBuildResultResponse.self,
            forKey: .build
        ) {
            self.build = nestedBuild
            return
        }

        let success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        let snakeCaseOutputPath = try container.decodeIfPresent(String.self, forKey: .output_path)
        let camelCaseOutputPath = try container.decodeIfPresent(String.self, forKey: .outputPath)
        let outputPath = snakeCaseOutputPath ?? camelCaseOutputPath ?? ""

        self.build = SiteMakerBuildResultResponse(
            success: success,
            output_path: outputPath
        )
    }

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

    init(success: Bool, output_path: String) {
        self.success = success
        self.output_path = output_path
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case output_path
        case outputPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
        let snakeCaseOutputPath = try container.decodeIfPresent(String.self, forKey: .output_path)
        let camelCaseOutputPath = try container.decodeIfPresent(String.self, forKey: .outputPath)
        self.output_path = snakeCaseOutputPath ?? camelCaseOutputPath ?? ""
    }
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
