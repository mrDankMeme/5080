import Foundation

enum BackendHTTPMethod: String, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"

    var id: String { rawValue }
}

enum EndpointBodyType {
    case none
    case multipartFormData
}

enum EndpointParameterLocation {
    case query
    case body
}

enum EndpointParameterKind {
    case text
    case integer
    case file
    case stringArray
    case enumeration([String])

    var isFile: Bool {
        if case .file = self {
            return true
        }
        return false
    }

    var isArray: Bool {
        if case .stringArray = self {
            return true
        }
        return false
    }

    var isInteger: Bool {
        if case .integer = self {
            return true
        }
        return false
    }
}

struct EndpointParameter: Identifiable {
    let key: String
    let title: String
    let kind: EndpointParameterKind
    let location: EndpointParameterLocation
    let required: Bool
    let placeholder: String
    let defaultValue: String?
    let note: String?

    init(
        key: String,
        title: String,
        kind: EndpointParameterKind,
        location: EndpointParameterLocation,
        required: Bool,
        placeholder: String,
        defaultValue: String?,
        note: String? = nil
    ) {
        self.key = key
        self.title = title
        self.kind = kind
        self.location = location
        self.required = required
        self.placeholder = placeholder
        self.defaultValue = defaultValue
        self.note = note
    }

    var id: String {
        "\(location)-\(key)"
    }

    var enumOptions: [String] {
        guard case .enumeration(let options) = kind else {
            return []
        }
        return options
    }
}

struct PhotoEndpointDefinition: Identifiable {
    let id: String
    let name: String
    let method: BackendHTTPMethod
    let path: String
    let bodyType: EndpointBodyType
    let parameters: [EndpointParameter]
}

struct EndpointGuideRU {
    let whatItDoes: String
    let whyItIsNeeded: String
}

enum EndpointDependencyKind {
    case providesData
    case needsData
}

struct EndpointDependencyHintRU: Identifiable {
    let kind: EndpointDependencyKind
    let text: String

    var id: String {
        "\(kind)-\(text)"
    }
}

struct PickedImageFile: Identifiable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let data: Data

    init(id: UUID = UUID(), fileName: String, mimeType: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

enum BackendDefaults {
    static let baseURLString = "https://aiapp.fotobudka.online/api/v1/"
    static let bearerToken = "245f6302-8239-4ff1-819e-f5c5bb2378a4"
    static let fallbackPrompt = "A cinematic portrait of a confident person in studio lighting"
    static let fallbackImageURL = "https://images.unsplash.com/photo-1544005313-94ddf0286df2"

    static var source: String {
        Bundle.main.bundleIdentifier ?? "com.nat.5043minimax"
    }
}

enum PhotoEndpointCatalog {
    static let endpoints: [PhotoEndpointDefinition] = [
        PhotoEndpointDefinition(
            id: "avatar/list",
            name: "Avatar list",
            method: .get,
            path: "avatar/list",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: true, placeholder: "ios-test-user-11", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/styles",
            name: "Styles",
            method: .get,
            path: "photo/styles",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .query, required: true, placeholder: "ru", defaultValue: "ru"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .query, required: true, placeholder: "f", defaultValue: "f"),
                .init(key: "tag", title: "tag", kind: .text, location: .query, required: false, placeholder: "056", defaultValue: nil),
                .init(key: "showAll", title: "showAll", kind: .text, location: .query, required: true, placeholder: "1", defaultValue: "1")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/popular",
            name: "Popular templates",
            method: .get,
            path: "photo/popular",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .query, required: true, placeholder: "ru", defaultValue: "ru"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .query, required: true, placeholder: "f", defaultValue: "f")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate",
            name: "Generate",
            method: .post,
            path: "photo/generate",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .query, required: true, placeholder: "471", defaultValue: "471"),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .query, required: true, placeholder: "36963", defaultValue: "36963")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generateInStyle",
            name: "Package generate",
            method: .post,
            path: "photo/generateInStyle",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "styleId", title: "styleId", kind: .integer, location: .query, required: true, placeholder: "365", defaultValue: "365"),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .query, required: true, placeholder: "36963", defaultValue: "36963"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .query, required: true, placeholder: "f", defaultValue: "f"),
                .init(key: "images[]", title: "images[]", kind: .stringArray, location: .query, required: false, placeholder: "https://...", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/godMode",
            name: "Generate in God Mode",
            method: .post,
            path: "photo/generate/godMode",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .query, required: true, placeholder: "41810", defaultValue: "41810", note: "ID аватара, который используем для генерации."),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: true, placeholder: "Prompt", defaultValue: BackendDefaults.fallbackPrompt, note: "Запрос на генерацию."),
                .init(
                    key: "aspectRatio",
                    title: "aspectRatio",
                    kind: .enumeration(["1:1", "3:4", "9:16", "16:9", "5:8", "3:2", "4:3"]),
                    location: .query,
                    required: false,
                    placeholder: "1:1",
                    defaultValue: "1:1",
                    note: "Output image aspect ratio."
                ),
                .init(key: "isMobApp", title: "isMobApp", kind: .integer, location: .query, required: false, placeholder: "0", defaultValue: "0", note: "Если передаем 0, то будет сгенерировано 2 фото, иначе 1."),
                .init(key: "isFreeGodMode", title: "isFreeGodMode", kind: .text, location: .query, required: true, placeholder: "1", defaultValue: "1", note: "Режим без аватара.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/ref",
            name: "Photo by ref",
            method: .post,
            path: "photo/generate/ref",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil),
                .init(
                    key: "aspectRatio",
                    title: "aspectRatio",
                    kind: .enumeration(["1:1", "3:4", "9:16", "16:9", "5:8", "3:2", "4:3"]),
                    location: .body,
                    required: true,
                    placeholder: "1:1",
                    defaultValue: "1:1"
                )
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/autoRef",
            name: "Photo by ref (auto prompt + nano banana pro)",
            method: .post,
            path: "photo/generate/autoRef",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "adapty_test_2", defaultValue: nil),
                .init(key: "referenceImageUrl", title: "referenceImageUrl", kind: .text, location: .body, required: true, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(key: "personImageUrl", title: "personImageUrl", kind: .text, location: .body, required: true, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/couple",
            name: "Couple photo generation",
            method: .post,
            path: "photo/generate/couple",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "manAvatarId", title: "manAvatarId", kind: .integer, location: .query, required: true, placeholder: "36506", defaultValue: "36506"),
                .init(key: "womanAvatarId", title: "womanAvatarId", kind: .integer, location: .query, required: true, placeholder: "36963", defaultValue: "36963")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/animation",
            name: "Animate photo",
            method: .post,
            path: "photo/generate/animation",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "photoId", title: "photoId", kind: .integer, location: .query, required: false, placeholder: "2358981", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: false, placeholder: "I put on red glasses", defaultValue: nil),
                .init(key: "photoUrl", title: "photoUrl", kind: .text, location: .query, required: false, placeholder: "https://...", defaultValue: nil),
                .init(key: "file", title: "file", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/txt2img",
            name: "Text 2 image",
            method: .post,
            path: "photo/generate/txt2img",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: false, placeholder: "Prompt", defaultValue: BackendDefaults.fallbackPrompt)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/txt2imgStyles",
            name: "Txt2Img Basic Styles",
            method: .get,
            path: "photo/txt2imgStyles",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .query, required: true, placeholder: "ru", defaultValue: "ru")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/txt2imgBasic",
            name: "Text 2 image NEW",
            method: .post,
            path: "photo/generate/txt2imgBasic",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: false, placeholder: "Prompt", defaultValue: BackendDefaults.fallbackPrompt),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .query, required: false, placeholder: "1968", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/img2imgStyles",
            name: "Img2Img Basic Styles",
            method: .get,
            path: "photo/img2imgStyles",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .query, required: true, placeholder: "ru", defaultValue: "ru")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/img2imgBasic",
            name: "Image 2 image NEW",
            method: .post,
            path: "photo/generate/img2imgBasic",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .body, required: false, placeholder: "Prompt", defaultValue: BackendDefaults.fallbackPrompt),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: false, placeholder: "1970", defaultValue: nil),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/styleTransfer",
            name: "Style transfer",
            method: .post,
            path: "photo/generate/styleTransfer",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: false, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .body, required: true, placeholder: "1", defaultValue: "1"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil),
                .init(key: "step", title: "step", kind: .integer, location: .body, required: true, placeholder: "1", defaultValue: "1")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/ghibli",
            name: "Ghibli",
            method: .post,
            path: "photo/generate/ghibli",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/generate/upscale",
            name: "Upscale",
            method: .post,
            path: "photo/generate/upscale",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-11", defaultValue: nil),
                .init(key: "jobId", title: "jobId", kind: .text, location: .body, required: true, placeholder: "b8d78e13-220a-40f1-81d7-3787344bb7a1", defaultValue: nil),
                .init(key: "image", title: "image", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/editorExamples",
            name: "Ai Editor Examples",
            method: .get,
            path: "photo/editorExamples",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: true, placeholder: "ios-test-user-1121", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/banana/generate",
            name: "Nano Banana",
            method: .post,
            path: "photo/banana/generate",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: false, placeholder: "Prompt", defaultValue: nil),
                .init(key: "imageUrl[]", title: "imageUrl[]", kind: .stringArray, location: .query, required: false, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(
                    key: "aspectRatio",
                    title: "aspectRatio",
                    kind: .enumeration(["1:1", "3:4", "9:16", "16:9", "5:8", "3:2", "4:3"]),
                    location: .query,
                    required: false,
                    placeholder: "4:3",
                    defaultValue: "4:3"
                )
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/banana/templated/generate",
            name: "Nano Banana with template",
            method: .post,
            path: "photo/banana/templated/generate",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "imageUrl[]", title: "imageUrl[]", kind: .stringArray, location: .query, required: false, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .query, required: true, placeholder: "1968", defaultValue: "1968")
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/kontext/generate",
            name: "Flux Kontext (Image to Image)",
            method: .post,
            path: "photo/kontext/generate",
            bodyType: .none,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .query, required: false, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .query, required: false, placeholder: "Prompt", defaultValue: nil),
                .init(key: "imageUrl", title: "imageUrl", kind: .text, location: .query, required: true, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(
                    key: "resolutionMode",
                    title: "resolutionMode",
                    kind: .enumeration(["auto", "match_input", "1:1", "16:9", "21:9", "3:2", "2:3", "4:5", "5:4", "3:4", "4:3", "9:16", "9:21"]),
                    location: .query,
                    required: true,
                    placeholder: "auto",
                    defaultValue: "auto"
                )
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/seedream",
            name: "Seedream",
            method: .post,
            path: "photo/seedream",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "prompt", title: "prompt", kind: .text, location: .body, required: true, placeholder: "Prompt", defaultValue: BackendDefaults.fallbackPrompt),
                .init(key: "imageUrls[]", title: "imageUrls[]", kind: .stringArray, location: .body, required: true, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(
                    key: "imageSize",
                    title: "imageSize",
                    kind: .enumeration(["square", "square_hd", "portrait_4_3", "portrait_16_9", "landscape_4_3", "landscape_16_9"]),
                    location: .body,
                    required: false,
                    placeholder: "square",
                    defaultValue: "square"
                )
            ]
        ),
        PhotoEndpointDefinition(
            id: "photo/seedream/templated",
            name: "Seedream with template",
            method: .post,
            path: "photo/seedream/templated",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "2b2c7...", defaultValue: nil),
                .init(key: "imageUrls[]", title: "imageUrls[]", kind: .stringArray, location: .body, required: true, placeholder: "https://...", defaultValue: BackendDefaults.fallbackImageURL),
                .init(
                    key: "imageSize",
                    title: "imageSize",
                    kind: .enumeration(["square", "square_hd", "portrait_4_3", "portrait_16_9", "landscape_4_3", "landscape_16_9"]),
                    location: .body,
                    required: false,
                    placeholder: "square",
                    defaultValue: "square"
                ),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: true, placeholder: "1968", defaultValue: "1968")
            ]
        ),
        PhotoEndpointDefinition(
            id: "creator/img2img",
            name: "Creator img2img (deprecated)",
            method: .post,
            path: "creator/img2img",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "token", title: "token", kind: .text, location: .body, required: false, placeholder: "BN1TVN...", defaultValue: nil),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .body, required: true, placeholder: "36963", defaultValue: "36963"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "creator/img2imgRef",
            name: "Creator img2imgRef",
            method: .post,
            path: "creator/img2imgRef",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "token", title: "token", kind: .text, location: .body, required: false, placeholder: "BN1TVN...", defaultValue: nil),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .body, required: true, placeholder: "36963", defaultValue: "36963"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil),
                .init(key: "step", title: "step", kind: .integer, location: .body, required: true, placeholder: "1...8", defaultValue: "4", note: "Reference Match. Допустимый диапазон: 1...8.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "effects/generate",
            name: "Effects generate",
            method: .post,
            path: "effects/generate",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "chatId", title: "chatId", kind: .text, location: .body, required: false, placeholder: "313226091", defaultValue: nil),
                .init(key: "userToken", title: "userToken", kind: .text, location: .body, required: false, placeholder: "9rmjk1...", defaultValue: nil),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: true, placeholder: "8", defaultValue: "8"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "fitting/generate",
            name: "Fitting generate",
            method: .post,
            path: "fitting/generate",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-1", defaultValue: nil),
                .init(key: "clothingId", title: "clothingId", kind: .integer, location: .body, required: false, placeholder: "59", defaultValue: nil, note: "Опционально. Либо clothingId, либо clothingImage."),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil, note: "Фото пользователя."),
                .init(key: "mask", title: "mask", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil, note: "Маска для fitting."),
                .init(key: "clothingImage", title: "clothingImage", kind: .file, location: .body, required: false, placeholder: "Pick image", defaultValue: nil, note: "Опционально. Либо clothingImage, либо clothingId.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "scenarios/generate",
            name: "Scenarios generate",
            method: .post,
            path: "scenarios/generate",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "chatId", title: "chatId", kind: .text, location: .body, required: false, placeholder: "313226091", defaultValue: nil),
                .init(key: "userToken", title: "userToken", kind: .text, location: .body, required: false, placeholder: "9rmjk1...", defaultValue: nil),
                .init(key: "mode", title: "mode", kind: .enumeration(["1", "2"]), location: .body, required: true, placeholder: "2", defaultValue: "2", note: "1 — по avatarId, 2 — по photo + gender."),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: false, placeholder: "Pick image", defaultValue: nil, note: "Используется при mode = 2."),
                .init(key: "avatarId", title: "avatarId", kind: .integer, location: .body, required: false, placeholder: "55645", defaultValue: nil, note: "Используется при mode = 1."),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .body, required: false, placeholder: "m", defaultValue: "f", note: "Используется при mode = 2."),
                .init(key: "scenarioId", title: "scenarioId", kind: .integer, location: .body, required: true, placeholder: "4", defaultValue: "4"),
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: false, placeholder: "ios-test-user-1121", defaultValue: nil, note: "В мобильном приложении передается userId, а chatId/userToken можно не передавать.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "styles/animate",
            name: "Styles animate",
            method: .post,
            path: "styles/animate",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: false, placeholder: "Pick image", defaultValue: nil),
                .init(key: "chatId", title: "chatId", kind: .text, location: .body, required: false, placeholder: "313226091", defaultValue: nil),
                .init(key: "userToken", title: "userToken", kind: .text, location: .body, required: false, placeholder: "9rmjk1...", defaultValue: nil),
                .init(key: "animationId", title: "animationId", kind: .integer, location: .body, required: false, placeholder: "2", defaultValue: nil, note: "Опционально. Если передаете userPrompt, animationId обычно не передают."),
                .init(key: "userPrompt", title: "userPrompt", kind: .text, location: .body, required: true, placeholder: "я танцую", defaultValue: "я танцую"),
                .init(key: "isCustomPrompt", title: "isCustomPrompt", kind: .integer, location: .body, required: false, placeholder: "1", defaultValue: "1", note: "1 — пользовательский prompt, 0 — prompt из шаблона.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "tools/futureChild",
            name: "Tools future child",
            method: .post,
            path: "tools/futureChild",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .body, required: true, placeholder: "ru", defaultValue: "ru"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .body, required: true, placeholder: "f", defaultValue: "f"),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: true, placeholder: "56", defaultValue: "56"),
                .init(key: "photoMan", title: "photoMan", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil, note: "Первое фото родителя."),
                .init(key: "photoWoman", title: "photoWoman", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil, note: "Второе фото родителя.")
            ]
        ),
        PhotoEndpointDefinition(
            id: "tools/grownUpChild",
            name: "Tools grown-up child",
            method: .post,
            path: "tools/grownUpChild",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .body, required: true, placeholder: "ru", defaultValue: "ru"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .body, required: true, placeholder: "f", defaultValue: "f"),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: true, placeholder: "2", defaultValue: "2"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil)
            ]
        ),
        PhotoEndpointDefinition(
            id: "tools/generate",
            name: "Tools generate",
            method: .post,
            path: "tools/generate",
            bodyType: .multipartFormData,
            parameters: [
                .init(key: "userId", title: "userId", kind: .text, location: .body, required: true, placeholder: "ios-test-user-1121", defaultValue: nil),
                .init(key: "lang", title: "lang", kind: .text, location: .body, required: true, placeholder: "ru", defaultValue: "ru"),
                .init(key: "templateId", title: "templateId", kind: .integer, location: .body, required: true, placeholder: "2", defaultValue: "2"),
                .init(key: "gender", title: "gender", kind: .enumeration(["f", "m"]), location: .body, required: true, placeholder: "f", defaultValue: "f"),
                .init(key: "photo", title: "photo", kind: .file, location: .body, required: true, placeholder: "Pick image", defaultValue: nil),
                .init(
                    key: "resolutionMode",
                    title: "resolutionMode",
                    kind: .enumeration(["auto", "match_input", "1:1", "16:9", "21:9", "3:2", "2:3", "4:5", "5:4", "3:4", "4:3", "9:16", "9:21"]),
                    location: .body,
                    required: false,
                    placeholder: "auto",
                    defaultValue: "auto"
                ),
                .init(key: "prompt", title: "prompt", kind: .text, location: .body, required: false, placeholder: "Prompt", defaultValue: nil)
            ]
        )
    ]

    static func guide(for endpointID: String) -> EndpointGuideRU {
        guidesRU[endpointID] ?? EndpointGuideRU(
            whatItDoes: "Выполняет серверную операцию по этому endpoint.",
            whyItIsNeeded: "Нужен для ручной проверки поведения backend в приложении."
        )
    }

    static func dependencyHints(for endpointID: String) -> [EndpointDependencyHintRU] {
        dependencyHintsRU[endpointID] ?? []
    }

    private static let guidesRU: [String: EndpointGuideRU] = [
        "avatar/list": EndpointGuideRU(
            whatItDoes: "Возвращает список аватаров текущего пользователя.",
            whyItIsNeeded: "Нужен, чтобы взять avatarId (поле id) и подставить его в endpoint-ы генерации."
        ),
        "photo/styles": EndpointGuideRU(
            whatItDoes: "Отдает список доступных стилей/категорий для фото.",
            whyItIsNeeded: "Нужен, чтобы понять, какие стили можно показать пользователю перед генерацией."
        ),
        "photo/popular": EndpointGuideRU(
            whatItDoes: "Возвращает популярные шаблоны, которые сейчас в топе.",
            whyItIsNeeded: "Нужен для экрана с быстрым выбором популярных шаблонов."
        ),
        "photo/generate": EndpointGuideRU(
            whatItDoes: "Запускает генерацию фото по шаблону и выбранному аватару.",
            whyItIsNeeded: "Основной endpoint, когда пользователь выбрал конкретный template."
        ),
        "photo/generateInStyle": EndpointGuideRU(
            whatItDoes: "Запускает пакетную генерацию внутри выбранного стиля.",
            whyItIsNeeded: "Нужен, когда надо получить несколько вариантов в одном стиле."
        ),
        "photo/generate/godMode": EndpointGuideRU(
            whatItDoes: "Генерирует фото в God Mode по тексту и параметрам кадра.",
            whyItIsNeeded: "Нужен для гибкой генерации, когда важны prompt и формат картинки."
        ),
        "photo/generate/ref": EndpointGuideRU(
            whatItDoes: "Генерирует фото на основе загруженного референса.",
            whyItIsNeeded: "Нужен для сценария “загрузил пример и получил похожий результат”."
        ),
        "photo/generate/autoRef": EndpointGuideRU(
            whatItDoes: "Генерация по ссылкам на изображения с автоподбором промпта.",
            whyItIsNeeded: "Нужен, когда не хочется писать prompt вручную, а есть картинки-ориентиры."
        ),
        "photo/generate/couple": EndpointGuideRU(
            whatItDoes: "Генерирует совместное фото для мужского и женского аватара.",
            whyItIsNeeded: "Нужен для сценариев пары/дуэтов."
        ),
        "photo/generate/animation": EndpointGuideRU(
            whatItDoes: "Анимирует фото или файл с учетом дополнительных параметров.",
            whyItIsNeeded: "Нужен для проверки перехода из статичной картинки в анимацию."
        ),
        "photo/generate/txt2img": EndpointGuideRU(
            whatItDoes: "Создает изображение только по текстовому описанию.",
            whyItIsNeeded: "Базовый сценарий text-to-image без дополнительных стилей."
        ),
        "photo/txt2imgStyles": EndpointGuideRU(
            whatItDoes: "Возвращает стили для базового text-to-image.",
            whyItIsNeeded: "Нужен для выбора стиля перед запуском txt2img Basic."
        ),
        "photo/generate/txt2imgBasic": EndpointGuideRU(
            whatItDoes: "Новая версия text-to-image с поддержкой templateId.",
            whyItIsNeeded: "Нужен, когда нужно управлять генерацией через конкретный шаблон."
        ),
        "photo/img2imgStyles": EndpointGuideRU(
            whatItDoes: "Отдает стили для режима image-to-image.",
            whyItIsNeeded: "Нужен для выбора стиля перед img2img генерацией."
        ),
        "photo/generate/img2imgBasic": EndpointGuideRU(
            whatItDoes: "Новая image-to-image генерация: берёт исходное фото + prompt.",
            whyItIsNeeded: "Нужен для улучшения/перерисовки уже существующей картинки."
        ),
        "photo/generate/styleTransfer": EndpointGuideRU(
            whatItDoes: "Переносит стиль аватара на загруженное фото.",
            whyItIsNeeded: "Нужен для сценария style transfer с контролем шага обработки."
        ),
        "photo/generate/ghibli": EndpointGuideRU(
            whatItDoes: "Преобразует фото в стилистику Ghibli.",
            whyItIsNeeded: "Нужен для тематического пресета/эффекта."
        ),
        "photo/generate/upscale": EndpointGuideRU(
            whatItDoes: "Повышает качество/разрешение изображения.",
            whyItIsNeeded: "Нужен после генерации, когда требуется более четкая картинка."
        ),
        "photo/editorExamples": EndpointGuideRU(
            whatItDoes: "Возвращает примеры для AI редактора.",
            whyItIsNeeded: "Нужен для заполнения витрины примеров в редакторе."
        ),
        "photo/banana/generate": EndpointGuideRU(
            whatItDoes: "Запускает генерацию в режиме Nano Banana.",
            whyItIsNeeded: "Нужен для отдельной модели/режима генерации с imageUrl и prompt."
        ),
        "photo/banana/templated/generate": EndpointGuideRU(
            whatItDoes: "Nano Banana генерация по templateId.",
            whyItIsNeeded: "Нужен для шаблонного сценария в Nano Banana."
        ),
        "photo/kontext/generate": EndpointGuideRU(
            whatItDoes: "Flux Kontext: image-to-image генерация с режимом резолюции.",
            whyItIsNeeded: "Нужен, когда важно контролировать соотношение сторон и режим выхода."
        ),
        "photo/seedream": EndpointGuideRU(
            whatItDoes: "Seedream генерация по prompt и массиву imageUrls.",
            whyItIsNeeded: "Нужен для продвинутого режима, где в генерацию передаются референсы."
        ),
        "photo/seedream/templated": EndpointGuideRU(
            whatItDoes: "Seedream генерация по шаблону templateId.",
            whyItIsNeeded: "Нужен для Seedream, когда генерация должна идти по заданному template."
        ),
        "creator/img2img": EndpointGuideRU(
            whatItDoes: "Запускает старую image-to-image генерацию в блоке Creator.",
            whyItIsNeeded: "Нужен для проверки легаси-сценария (endpoint помечен как deprecated)."
        ),
        "creator/img2imgRef": EndpointGuideRU(
            whatItDoes: "Запускает image-to-image генерацию с параметром Reference Match (step).",
            whyItIsNeeded: "Нужен, когда надо сравнить силу привязки к референсу (step 1...8)."
        ),
        "effects/generate": EndpointGuideRU(
            whatItDoes: "Накладывает выбранный эффект/шаблон на загруженное фото.",
            whyItIsNeeded: "Нужен для теста эффектов, где шаблон задается через templateId."
        ),
        "fitting/generate": EndpointGuideRU(
            whatItDoes: "Генерирует примерку одежды по фото пользователя и маске.",
            whyItIsNeeded: "Нужен для сценария virtual try-on (примерка)."
        ),
        "scenarios/generate": EndpointGuideRU(
            whatItDoes: "Запускает генерацию по выбранному сценарию (scenarioId).",
            whyItIsNeeded: "Нужен для теста двух режимов: по avatarId (mode=1) или по фото+gender (mode=2)."
        ),
        "styles/animate": EndpointGuideRU(
            whatItDoes: "Анимирует фото по animationId или userPrompt.",
            whyItIsNeeded: "Нужен для проверки блока анимации со своим prompt."
        ),
        "tools/futureChild": EndpointGuideRU(
            whatItDoes: "Генерирует фото будущего ребенка по двум фото родителей.",
            whyItIsNeeded: "Нужен для сценария, где сразу требуются 2 отдельных входных фото."
        ),
        "tools/grownUpChild": EndpointGuideRU(
            whatItDoes: "Генерирует версию ребенка во взрослом возрасте по одному фото.",
            whyItIsNeeded: "Нужен для тематического сценария age progression."
        ),
        "tools/generate": EndpointGuideRU(
            whatItDoes: "Генерация инструмента по templateId + фото пользователя.",
            whyItIsNeeded: "Нужен как универсальный endpoint tools для шаблонной генерации."
        )
    ]

    private static let dependencyHintsRU: [String: [EndpointDependencyHintRU]] = [
        "avatar/list": [
            EndpointDependencyHintRU(
                kind: .providesData,
                text: "Из ответа берут avatarId (это поле data[].id). Этот avatarId нужен в photo/generate, photo/generateInStyle, photo/generate/godMode и других endpoint-ах."
            )
        ],
        "photo/styles": [
            EndpointDependencyHintRU(
                kind: .providesData,
                text: "Из ответа обычно берут styleId. Этот styleId потом нужен в POST photo/generateInStyle."
            )
        ],
        "photo/popular": [
            EndpointDependencyHintRU(
                kind: .providesData,
                text: "Из ответа берут templateId. Этот templateId потом нужен в endpoint-ах с параметром templateId."
            ),
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Если GET photo/popular вернул 0 элементов, берите templateId из GET photo/styles (поле templates[].id), а также из GET photo/txt2imgStyles и GET photo/img2imgStyles."
            ),
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "На части окружений photo/popular может стабильно возвращать пустой массив. Это не всегда ошибка клиента: используйте альтернативные источники templateId."
            )
        ],
        "photo/txt2imgStyles": [
            EndpointDependencyHintRU(
                kind: .providesData,
                text: "Стили/шаблоны из этого ответа обычно используются для templateId в POST photo/generate/txt2imgBasic."
            )
        ],
        "photo/img2imgStyles": [
            EndpointDependencyHintRU(
                kind: .providesData,
                text: "Стили/шаблоны из ответа можно использовать как templateId в POST photo/generate/img2imgBasic."
            )
        ],
        "photo/generateInStyle": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужен styleId, который обычно берут из GET photo/styles."
            ),
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "images[] здесь ожидает ссылки (URL), а не файлы напрямую. Можно выбрать фото в пикере и получить URL через upload-блок под endpoint."
            )
        ],
        "photo/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "templateId обычно берут из списков шаблонов (например GET photo/popular)."
            )
        ],
        "photo/generate/txt2imgBasic": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Если используете templateId, его обычно берут из GET photo/txt2imgStyles или GET photo/popular."
            )
        ],
        "photo/generate/img2imgBasic": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Если используете templateId, его обычно берут из GET photo/img2imgStyles."
            )
        ],
        "photo/banana/templated/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "templateId обычно берут из endpoint-ов, которые отдают списки шаблонов."
            )
        ],
        "photo/seedream/templated": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "templateId обычно берут из endpoint-ов со списком шаблонов."
            ),
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "imageUrls[] здесь ожидает ссылки (URL), а не локальные файлы."
            )
        ],
        "photo/seedream": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "imageUrls[] — это именно массив ссылок (URL). Обычно сюда подставляют URL ранее полученных изображений."
            )
        ],
        "photo/kontext/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "imageUrl обычно берут из результата предыдущей генерации или из внешней ссылки."
            )
        ],
        "photo/generate/autoRef": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "referenceImageUrl и personImageUrl — это ссылки. Файл напрямую не отправляется в endpoint, но можно выбрать фото в пикере и получить URL через upload-блок."
            ),
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Если получаете HTTP 404, значит этот маршрут не раскатан на текущем backend-окружении (документация может быть свежее прода)."
            )
        ],
        "photo/generate/animation": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "photoId/photoUrl обычно получают из предыдущих генераций."
            )
        ],
        "photo/generate/upscale": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "jobId обычно приходит из результата ранее запущенной задачи генерации."
            )
        ],
        "creator/img2img": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужен avatarId. Обычно его берут из GET avatar/list -> data[].id."
            )
        ],
        "creator/img2imgRef": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужен avatarId из GET avatar/list и step в диапазоне 1...8."
            )
        ],
        "effects/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужен templateId эффекта. Его берут из каталога эффектов/шаблонов этого окружения."
            )
        ],
        "fitting/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Передайте photo + mask. Дополнительно можно передать либо clothingId, либо clothingImage (обычно одно из двух)."
            )
        ],
        "scenarios/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "mode = 1: нужен avatarId (обычно из GET avatar/list). mode = 2: нужен photo и обычно gender."
            )
        ],
        "styles/animate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Обычно используют userPrompt + isCustomPrompt=1. animationId можно не передавать, если есть свой prompt."
            )
        ],
        "tools/futureChild": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужны ДВА файла: photoMan и photoWoman. templateId обычно берут из GET tools."
            )
        ],
        "tools/grownUpChild": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужно одно фото + templateId. templateId обычно берут из GET tools."
            )
        ],
        "tools/generate": [
            EndpointDependencyHintRU(
                kind: .needsData,
                text: "Нужно одно фото + templateId. templateId обычно берут из GET tools."
            )
        ]
    ]
}

enum ParameterGuideCatalog {
    static func description(for key: String) -> String {
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: "[]", with: "")

        switch normalized {
        case "userid":
            return "ID текущего тестового пользователя. Подставляется автоматически из блока Auth."
        case "lang":
            return "Язык ответа backend (обычно ru или en)."
        case "gender":
            return "Пол пользователя/аватара: f или m."
        case "tag":
            return "Дополнительный фильтр стилей (опционально)."
        case "showall":
            return "Показывать весь список (1) или ограниченный (0)."
        case "templateid":
            return "ID шаблона, по которому будет генерация. Чаще всего берут из templates[].id в GET photo/styles, GET photo/popular, GET photo/txt2imgStyles, GET photo/img2imgStyles."
        case "scenarioid":
            return "ID сценария, который запускаем в scenarios/generate."
        case "styleid":
            return "ID стиля/пакета генерации."
        case "avatarid":
            return "ID выбранного аватара. Берется из GET avatar/list -> data[].id или из GET user/profile -> data.avatars[].id."
        case "manavatarid":
            return "ID мужского аватара для пары."
        case "womanavatarid":
            return "ID женского аватара для пары."
        case "clothingid":
            return "ID готовой одежды для fitting. Передают либо clothingId, либо clothingImage."
        case "mode":
            return "Режим сценария: 1 — по avatarId, 2 — по photo + gender."
        case "prompt":
            return "Текстовое описание того, что нужно сгенерировать."
        case "userprompt":
            return "Пользовательский prompt для анимации."
        case "aspectratio":
            return "Соотношение сторон итогового изображения."
        case "ismobapp":
            return "Флаг мобильного режима. 0 и 1 могут менять поведение генерации."
        case "isfreegodmode":
            return "Флаг бесплатного режима God Mode."
        case "iscustomprompt":
            return "Флаг источника prompt: 1 — пользовательский, 0 — шаблонный."
        case "photo":
            return "Фото-файл, который вы загружаете с устройства."
        case "photoman":
            return "Первое фото родителя для futureChild."
        case "photowoman":
            return "Второе фото родителя для futureChild."
        case "mask":
            return "Файл-маска для fitting/generate."
        case "clothingimage":
            return "Картинка одежды для fitting. Передают вместо clothingId."
        case "file":
            return "Файл изображения для обработки/анимации."
        case "image":
            return "Изображение-файл для upscale или других операций."
        case "photoid":
            return "ID уже созданного фото в системе."
        case "photourl":
            return "Ссылка на исходное фото."
        case "referenceimageurl":
            return "Ссылка на референс, из которого берем стиль/идею. Для autoRef можно выбрать фото из галереи через блок upload."
        case "personimageurl":
            return "Ссылка на фото человека, которое используем в генерации. Для autoRef можно выбрать фото из галереи через блок upload."
        case "imageurl":
            return "Ссылка на изображение (или список ссылок) для image-to-image/референсов."
        case "imageurls", "images":
            return "Список ссылок на изображения-референсы. Точный лимит зависит от конкретного endpoint."
        case "resolutionmode":
            return "Режим выбора выходного размера/пропорции."
        case "step":
            return "Шаг/интенсивность обработки в style transfer."
        case "jobid":
            return "ID задачи/джобы, которую нужно апскейлить."
        case "imagesize":
            return "Готовый пресет размера итоговой картинки."
        case "token":
            return "Сервисный токен endpoint-а (если backend ожидает его в body)."
        case "usertoken":
            return "Сервисный токен пользователя (legacy формат некоторых endpoint-ов)."
        case "chatid":
            return "ID чата/сессии для legacy endpoint-ов."
        case "animationid":
            return "ID готового шаблона анимации."
        default:
            return "Служебный параметр endpoint для формирования запроса."
        }
    }
}
