import Foundation
import Combine
import SwiftUI

@MainActor
final class BackendTestLabViewModel: ObservableObject {
    @Published var baseURLString: String = BackendDefaults.baseURLString
    @Published var bearerToken: String = BackendDefaults.bearerToken
    @Published var source: String = BackendDefaults.source
    @Published var lang: String = "ru"

    @Published var userId: String = UserIdStorage.loadOrCreate() {
        didSet {
            UserIdStorage.save(userId.trimmed)
            syncUserIdToPhotoFields()
        }
    }
    @Published var gender: String = "f"
    @Published var productId: String = "10"

    @Published var availableGenerationsText: String = "-"
    @Published var activePlanText: String = "-"

    @Published var photoTextValues: [String: [String: String]] = [:]
    @Published var photoArrayValues: [String: [String: [String]]] = [:]
    @Published var photoFiles: [String: [String: [PickedImageFile]]] = [:]
    @Published var endpointObjectPreviews: [String: EndpointObjectPreview] = [:]
    @Published var endpointPostResults: [String: EndpointPostResult] = [:]

    @Published var isLoading = false
    @Published var statusLine = "Ready"

    private let service = BackendTestService()
    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private let pollingIntervalNanoseconds: UInt64 = 1_000_000_000
    private let maxPollingAttempts = 180
    private let objectPreviewEndpointIDs: Set<String> = [
        "avatar/list",
        "photo/styles",
        "photo/popular",
        "photo/txt2imgStyles",
        "photo/img2imgStyles",
        "photo/editorExamples"
    ]

    var photoEndpoints: [PhotoEndpointDefinition] {
        PhotoEndpointCatalog.endpoints
    }

    init() {
        resetPhotoDefaultsForAllEndpoints()
        syncUserIdToPhotoFields()
    }

    func resetPhotoDefaultsForAllEndpoints() {
        var freshTextValues: [String: [String: String]] = [:]
        var freshArrayValues: [String: [String: [String]]] = [:]
        var freshFileValues: [String: [String: [PickedImageFile]]] = [:]

        for endpoint in photoEndpoints {
            var endpointText: [String: String] = [:]
            var endpointArrays: [String: [String]] = [:]
            var endpointFiles: [String: [PickedImageFile]] = [:]

            for parameter in endpoint.parameters {
                switch parameter.kind {
                case .stringArray:
                    if let value = parameter.defaultValue, !value.isEmpty {
                        endpointArrays[parameter.key] = [value]
                    } else {
                        endpointArrays[parameter.key] = [""]
                    }

                case .enumeration(let options):
                    if let value = parameter.defaultValue, !value.isEmpty {
                        endpointText[parameter.key] = value
                    } else if let first = options.first {
                        endpointText[parameter.key] = first
                    } else {
                        endpointText[parameter.key] = ""
                    }

                case .file:
                    endpointFiles[parameter.key] = []

                case .text, .integer:
                    if parameter.key == "userId" {
                        endpointText[parameter.key] = userId.trimmed
                    } else {
                        endpointText[parameter.key] = parameter.defaultValue ?? ""
                    }
                }
            }

            freshTextValues[endpoint.id] = endpointText
            freshArrayValues[endpoint.id] = endpointArrays
            freshFileValues[endpoint.id] = endpointFiles
        }

        photoTextValues = freshTextValues
        photoArrayValues = freshArrayValues
        photoFiles = freshFileValues
    }

    func endpointGuide(for endpointID: String) -> EndpointGuideRU {
        PhotoEndpointCatalog.guide(for: endpointID)
    }

    func parameterGuide(for key: String) -> String {
        ParameterGuideCatalog.description(for: key)
    }

    func dependencyHints(for endpointID: String) -> [EndpointDependencyHintRU] {
        PhotoEndpointCatalog.dependencyHints(for: endpointID)
    }

    func supportsObjectPreview(endpointID: String) -> Bool {
        objectPreviewEndpointIDs.contains(endpointID)
    }

    func objectPreview(for endpointID: String) -> EndpointObjectPreview? {
        endpointObjectPreviews[endpointID]
    }

    func postResult(for endpointID: String) -> EndpointPostResult? {
        endpointPostResults[endpointID]
    }

    func prefillExplanation(for parameter: EndpointParameter, endpointID: String) -> ParameterPrefillExplanation? {
        if parameter.key == "userId" {
            return ParameterPrefillExplanation(
                value: userId.trimmed,
                source: "Из блока Auth + локальное сохранение в приложении (UserDefaults).",
                why: "Чтобы один раз создать тестового пользователя и дальше не терять его между запусками.",
                alternatives: "Любой валидный userId, зарегистрированный через POST user/login."
            )
        }

        if parameter.key == "gender" {
            return ParameterPrefillExplanation(
                value: gender.trimmed,
                source: "Из блока Auth (переключатель gender).",
                why: "Пол часто нужен сразу в нескольких endpoint, поэтому вынесен в одно место.",
                alternatives: "Только значения из API: f или m."
            )
        }

        if parameter.key == "lang" {
            return ParameterPrefillExplanation(
                value: lang.trimmed,
                source: "Из блока Connection (поле lang).",
                why: "Язык ответа backend должен быть единообразным для тестов.",
                alternatives: "Обычно ru или en (в зависимости от того, что поддерживает backend)."
            )
        }

        if case .enumeration(let options) = parameter.kind, parameter.defaultValue == nil, let first = options.first {
            return ParameterPrefillExplanation(
                value: first,
                source: "Автовыбор первого варианта из списка enum.",
                why: "Чтобы форма не была пустой и endpoint можно было сразу запустить.",
                alternatives: "Доступные варианты: \(options.joined(separator: ", "))."
            )
        }

        guard let defaultValue = parameter.defaultValue?.trimmed, !defaultValue.isEmpty else {
            return nil
        }

        let source: String
        if defaultValue == BackendDefaults.fallbackPrompt {
            source = "Тестовый fallback из APITests (`BackendDefaults.fallbackPrompt`)."
        } else if defaultValue == BackendDefaults.fallbackImageURL {
            source = "Тестовый fallback URL из APITests (`BackendDefaults.fallbackImageURL`)."
        } else {
            source = "Значение из документации `Fotobudka.apidog.json` (пример параметра) или безопасный тестовый пресет в проекте."
        }

        return ParameterPrefillExplanation(
            value: defaultValue,
            source: source,
            why: "Подставлено заранее, чтобы endpoint можно было проверить в 1 тап без ручного заполнения.",
            alternatives: alternativesForParameter(parameter)
        )
    }

    func bindingForText(endpointID: String, key: String) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.photoTextValues[endpointID]?[key] ?? ""
            },
            set: { [weak self] newValue in
                var endpointValues = self?.photoTextValues[endpointID] ?? [:]
                endpointValues[key] = newValue
                self?.photoTextValues[endpointID] = endpointValues
            }
        )
    }

    func valuesForArray(endpointID: String, key: String) -> [String] {
        photoArrayValues[endpointID]?[key] ?? [""]
    }

    func updateArrayValue(endpointID: String, key: String, index: Int, value: String) {
        var endpointArrays = photoArrayValues[endpointID] ?? [:]
        var values = endpointArrays[key] ?? [""]
        guard values.indices.contains(index) else { return }
        values[index] = value
        endpointArrays[key] = values
        photoArrayValues[endpointID] = endpointArrays
    }

    func addArrayValue(endpointID: String, key: String) {
        var endpointArrays = photoArrayValues[endpointID] ?? [:]
        var values = endpointArrays[key] ?? [""]
        values.append("")
        endpointArrays[key] = values
        photoArrayValues[endpointID] = endpointArrays
    }

    func removeArrayValue(endpointID: String, key: String, index: Int) {
        var endpointArrays = photoArrayValues[endpointID] ?? [:]
        var values = endpointArrays[key] ?? [""]
        guard values.indices.contains(index) else { return }

        values.remove(at: index)
        if values.isEmpty {
            values = [""]
        }
        endpointArrays[key] = values
        photoArrayValues[endpointID] = endpointArrays
    }

    func files(endpointID: String, key: String) -> [PickedImageFile] {
        photoFiles[endpointID]?[key] ?? []
    }

    func setFiles(_ files: [PickedImageFile], endpointID: String, key: String) {
        var endpointFiles = photoFiles[endpointID] ?? [:]
        endpointFiles[key] = files
        photoFiles[endpointID] = endpointFiles
    }

    func removeFile(endpointID: String, key: String, id: UUID) {
        var endpointFiles = photoFiles[endpointID] ?? [:]
        var files = endpointFiles[key] ?? []
        files.removeAll { $0.id == id }
        endpointFiles[key] = files
        photoFiles[endpointID] = endpointFiles
    }

    func login() {
        let cleanedUser = userId.trimmed
        let cleanedGender = gender.trimmed.lowercased()
        let cleanedSource = source.trimmed

        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/login")
            return
        }

        guard !cleanedGender.isEmpty else {
            appendValidationError("gender is required for user/login")
            return
        }

        guard !cleanedSource.isEmpty else {
            appendValidationError("source is required for user/login")
            return
        }

        let queryItems = [
            URLQueryItem(name: "userId", value: cleanedUser),
            URLQueryItem(name: "gender", value: cleanedGender),
            URLQueryItem(name: "source", value: cleanedSource),
            URLQueryItem(name: "isFb", value: "0"),
            URLQueryItem(name: "payments", value: "1")
        ]

        runRequest(
            title: "POST user/login",
            method: .post,
            path: "user/login",
            queryItems: queryItems,
            bodyType: .none
        ) { [weak self] response in
            self?.hydrateUserState(from: response.data)
        }
    }

    func fetchProfile() {
        let cleanedUser = userId.trimmed
        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/profile")
            return
        }

        runRequest(
            title: "GET user/profile",
            method: .get,
            path: "user/profile",
            queryItems: [URLQueryItem(name: "userId", value: cleanedUser)],
            bodyType: .none
        ) { [weak self] response in
            self?.hydrateUserState(from: response.data)
        }
    }

    func setFreeGenerations() {
        let cleanedUser = userId.trimmed
        let cleanedSource = source.trimmed

        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/setFreeGenerations")
            return
        }

        guard !cleanedSource.isEmpty else {
            appendValidationError("source is required for user/setFreeGenerations")
            return
        }

        runRequest(
            title: "POST user/setFreeGenerations",
            method: .post,
            path: "user/setFreeGenerations",
            queryItems: [
                URLQueryItem(name: "userId", value: cleanedUser),
                URLQueryItem(name: "source", value: cleanedSource)
            ],
            bodyType: .none,
            onResponse: nil
        )
    }

    func addGenerations() {
        let cleanedUser = userId.trimmed
        let cleanedSource = source.trimmed
        let cleanedProductId = productId.trimmed

        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/addGenerations")
            return
        }

        guard !cleanedProductId.isEmpty else {
            appendValidationError("productId is required for user/addGenerations")
            return
        }

        guard Int(cleanedProductId) != nil else {
            appendValidationError("productId must be integer")
            return
        }

        runRequest(
            title: "POST user/addGenerations",
            method: .post,
            path: "user/addGenerations",
            queryItems: [
                URLQueryItem(name: "userId", value: cleanedUser),
                URLQueryItem(name: "productId", value: cleanedProductId),
                URLQueryItem(name: "source", value: cleanedSource)
            ],
            bodyType: .none,
            onResponse: nil
        )
    }

    func collectTokens() {
        let cleanedUser = userId.trimmed
        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/collectTokens")
            return
        }

        runRequest(
            title: "POST user/collectTokens",
            method: .post,
            path: "user/collectTokens",
            queryItems: [],
            bodyType: .multipartFormData,
            multipartFields: ["userId": [cleanedUser]],
            files: [],
            onResponse: nil
        )
    }

    func availableBonuses() {
        let cleanedUser = userId.trimmed
        guard !cleanedUser.isEmpty else {
            appendValidationError("userId is required for user/availableBonuses")
            return
        }

        runRequest(
            title: "GET user/availableBonuses",
            method: .get,
            path: "user/availableBonuses",
            queryItems: [URLQueryItem(name: "userId", value: cleanedUser)],
            bodyType: .none,
            onResponse: nil
        )
    }

    func executePhotoEndpoint(endpointID: String) {
        guard let endpoint = photoEndpoints.first(where: { $0.id == endpointID }) else { return }

        var queryItems: [URLQueryItem] = []
        var multipartFields: [String: [String]] = [:]
        var files: [MultipartUploadFile] = []
        var missingRequired: [String] = []

        for parameter in endpoint.parameters {
            switch parameter.kind {
            case .file:
                let pickedFiles = photoFiles[endpointID]?[parameter.key] ?? []
                if pickedFiles.isEmpty {
                    if parameter.required {
                        missingRequired.append(parameter.title)
                    }
                    continue
                }

                let mappedFiles = pickedFiles.map {
                    MultipartUploadFile(
                        fieldName: parameter.key,
                        fileName: $0.fileName,
                        mimeType: $0.mimeType,
                        data: $0.data
                    )
                }

                switch parameter.location {
                case .query:
                    continue
                case .body:
                    files.append(contentsOf: mappedFiles)
                }

            case .stringArray:
                let values = normalizedArrayValues(for: parameter, endpointID: endpointID)
                if values.isEmpty {
                    if parameter.required {
                        missingRequired.append(parameter.title)
                    }
                    continue
                }

                switch parameter.location {
                case .query:
                    values.forEach { value in
                        queryItems.append(URLQueryItem(name: parameter.key, value: value))
                    }
                case .body:
                    multipartFields[parameter.key] = values
                }

            case .text, .integer, .enumeration:
                let value = normalizedTextValue(for: parameter, endpointID: endpointID)
                if value.isEmpty {
                    if parameter.required {
                        missingRequired.append(parameter.title)
                    }
                    continue
                }

                switch parameter.location {
                case .query:
                    queryItems.append(URLQueryItem(name: parameter.key, value: value))
                case .body:
                    multipartFields[parameter.key, default: []].append(value)
                }
            }
        }

        if !missingRequired.isEmpty {
            appendValidationError("\(endpoint.method.rawValue) \(endpoint.path): заполни поля \(missingRequired.joined(separator: ", "))")
            return
        }

        if endpoint.method == .post {
            cancelPolling(for: endpoint.id)
            endpointPostResults[endpoint.id] = EndpointPostResult(
                state: .running,
                httpCode: nil,
                backendStatus: nil,
                message: "Запрос отправлен. Ждем ответ backend.",
                jobId: nil,
                generationId: nil,
                imageURLs: [],
                fields: [],
                rawJSON: nil,
                pollAttempt: 0,
                shouldPoll: false
            )
        }

        runRequest(
            title: "\(endpoint.method.rawValue) \(endpoint.path)",
            method: endpoint.method,
            path: endpoint.path,
            queryItems: queryItems,
            bodyType: endpoint.bodyType,
            multipartFields: multipartFields,
            files: files,
            onResponse: { [weak self] response in
                self?.storeObjectPreviewIfNeeded(endpointID: endpoint.id, method: endpoint.method, response: response)
                self?.storePostResultIfNeeded(endpointID: endpoint.id, method: endpoint.method, response: response)
            },
            onError: { [weak self] error in
                guard endpoint.method == .post else { return }
                self?.cancelPolling(for: endpoint.id)
                self?.endpointPostResults[endpoint.id] = EndpointPostResult(
                    state: .failure,
                    httpCode: nil,
                    backendStatus: nil,
                    message: "Ошибка запроса: \(error.localizedDescription)",
                    jobId: nil,
                    generationId: nil,
                    imageURLs: [],
                    fields: [],
                    rawJSON: nil,
                    pollAttempt: 0,
                    shouldPoll: false
                )
            }
        )
    }

    func uploadAndApplyImageURLs(endpointID: String, files: [PickedImageFile]) {
        let cleanedUser = userId.trimmed
        guard !cleanedUser.isEmpty else {
            appendValidationError("Сначала укажи userId в блоке Auth")
            return
        }

        let maxCount = maxUploadCount(for: endpointID)
        let preparedFiles = Array(files.prefix(maxCount))
        guard !preparedFiles.isEmpty else {
            appendValidationError("Выбери хотя бы одно фото")
            return
        }

        if endpointID == "photo/generate/autoRef", preparedFiles.count < 2 {
            appendValidationError("Для photo/generate/autoRef нужно выбрать 2 фото")
            return
        }

        guard !isLoading else { return }
        isLoading = true
        statusLine = "Uploading \(preparedFiles.count) image(s) for \(endpointID)..."

        Task {
            defer { isLoading = false }

            do {
                let uploadFiles = preparedFiles.map { file in
                    MultipartUploadFile(
                        fieldName: "files[]",
                        fileName: file.fileName,
                        mimeType: file.mimeType,
                        data: file.data
                    )
                }

                let response = try await service.sendRequest(
                    baseURLString: baseURLString.trimmed,
                    bearerToken: bearerToken.trimmed,
                    method: .post,
                    path: "services/upload",
                    queryItems: [],
                    bodyType: .multipartFormData,
                    multipartFields: ["userId": [cleanedUser]],
                    files: uploadFiles
                )

                let urls = extractURLs(from: response.data)
                guard !urls.isEmpty else {
                    statusLine = "services/upload: не удалось извлечь URL из ответа"
                    return
                }

                applyUploadedURLs(endpointID: endpointID, urls: urls)
            } catch {
                appendErrorLog(title: "POST services/upload", error: error)
            }
        }
    }

    private func normalizedTextValue(for parameter: EndpointParameter, endpointID: String) -> String {
        if parameter.key == "userId" {
            return userId.trimmed
        }

        let current = (photoTextValues[endpointID]?[parameter.key] ?? "").trimmed
        if !current.isEmpty {
            return current
        }

        if parameter.key == "gender" {
            return gender.trimmed
        }

        if parameter.key == "lang" {
            return lang.trimmed
        }

        return ""
    }

    private func normalizedArrayValues(for parameter: EndpointParameter, endpointID: String) -> [String] {
        (photoArrayValues[endpointID]?[parameter.key] ?? [])
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
    }

    private func alternativesForParameter(_ parameter: EndpointParameter) -> String {
        switch parameter.kind {
        case .enumeration(let options):
            return "Доступные варианты: \(options.joined(separator: ", "))."
        case .stringArray:
            if parameter.key.lowercased().contains("image") {
                return "Можно передать несколько значений; обычно это список URL изображений."
            }
            return "Можно передать несколько строковых значений."
        case .file:
            return "Можно выбрать 1 или несколько файлов (если endpoint поддерживает несколько файлов одного поля)."
        case .integer:
            if parameter.key.lowercased().contains("id") {
                return "Можно указать любой валидный ID нужной сущности (templateId/styleId/avatarId/jobId и т.д.)."
            }
            if ["showall", "ismobapp", "isfreegodmode"].contains(parameter.key.lowercased()) {
                return "Обычно используют флаги 0 или 1."
            }
            return "Можно передать другое целое число, если backend его допускает."
        case .text:
            let normalizedKey = parameter.key.lowercased()
            if normalizedKey.contains("url") {
                return "Можно передать другой валидный URL."
            }
            if normalizedKey == "prompt" {
                return "Можно передать любой другой текстовый prompt."
            }
            if normalizedKey == "tag" {
                return "Можно оставить пустым или подставить другой тег-фильтр."
            }
            return "Можно передать другую строку в формате, который ожидает backend."
        }
    }

    private func runRequest(
        title: String,
        method: BackendHTTPMethod,
        path: String,
        queryItems: [URLQueryItem],
        bodyType: EndpointBodyType,
        multipartFields: [String: [String]] = [:],
        files: [MultipartUploadFile] = [],
        onResponse: ((BackendRawResponse) -> Void)?,
        onError: ((Error) -> Void)? = nil
    ) {
        guard !isLoading else { return }
        isLoading = true
        statusLine = "Running \(title)..."

        Task {
            defer { isLoading = false }

            do {
                let response = try await service.sendRequest(
                    baseURLString: baseURLString.trimmed,
                    bearerToken: bearerToken.trimmed,
                    method: method,
                    path: path,
                    queryItems: queryItems,
                    bodyType: bodyType,
                    multipartFields: multipartFields,
                    files: files
                )

                onResponse?(response)
                appendResponseLog(title: title, response: response)
            } catch {
                onError?(error)
                appendErrorLog(title: title, error: error)
            }
        }
    }

    private func storeObjectPreviewIfNeeded(endpointID: String, method: BackendHTTPMethod, response: BackendRawResponse) {
        guard method == .get, supportsObjectPreview(endpointID: endpointID) else {
            return
        }

        guard response.isSuccess else {
            endpointObjectPreviews[endpointID] = EndpointObjectPreview(
                totalCount: 0,
                shownCount: 0,
                items: [],
                note: "HTTP \(response.statusCode). Объекты не получены."
            )
            return
        }

        endpointObjectPreviews[endpointID] = makeObjectPreview(endpointID: endpointID, data: response.data)
    }

    private func storePostResultIfNeeded(endpointID: String, method: BackendHTTPMethod, response: BackendRawResponse) {
        guard method == .post else {
            return
        }

        let snapshot = makePostResultSnapshot(response: response, pollAttempt: 0, fallbackMessage: nil)
        endpointPostResults[endpointID] = snapshot

        if snapshot.shouldPoll {
            startPollingForPostResult(endpointID: endpointID, initial: snapshot)
        }
    }

    private func startPollingForPostResult(endpointID: String, initial: EndpointPostResult) {
        cancelPolling(for: endpointID)

        let task = Task { [weak self] in
            guard let self else { return }

            for attempt in 1...maxPollingAttempts {
                if Task.isCancelled {
                    return
                }

                do {
                    let response = try await pollStatusResponse(jobId: initial.jobId, generationId: initial.generationId)
                    let fallback = "Поллинг каждую 1с: попытка \(attempt)/\(maxPollingAttempts)."
                    let snapshot = makePostResultSnapshot(response: response, pollAttempt: attempt, fallbackMessage: fallback)
                    endpointPostResults[endpointID] = snapshot

                    if !snapshot.shouldPoll {
                        pollingTasks[endpointID] = nil
                        return
                    }
                } catch {
                    endpointPostResults[endpointID] = EndpointPostResult(
                        state: .failure,
                        httpCode: nil,
                        backendStatus: nil,
                        message: "Ошибка поллинга: \(error.localizedDescription)",
                        jobId: initial.jobId,
                        generationId: initial.generationId,
                        imageURLs: [],
                        fields: [],
                        rawJSON: nil,
                        pollAttempt: attempt,
                        shouldPoll: false
                    )
                    pollingTasks[endpointID] = nil
                    return
                }

                try? await Task.sleep(nanoseconds: pollingIntervalNanoseconds)
            }

            endpointPostResults[endpointID] = EndpointPostResult(
                state: .timeout,
                httpCode: nil,
                backendStatus: initial.backendStatus,
                message: "Поллинг остановлен по таймауту. Попробуй снова или проверь jobId вручную.",
                jobId: initial.jobId,
                generationId: initial.generationId,
                imageURLs: initial.imageURLs,
                fields: initial.fields,
                rawJSON: initial.rawJSON,
                pollAttempt: maxPollingAttempts,
                shouldPoll: false
            )
            pollingTasks[endpointID] = nil
        }

        pollingTasks[endpointID] = task
    }

    private func cancelPolling(for endpointID: String) {
        pollingTasks[endpointID]?.cancel()
        pollingTasks[endpointID] = nil
    }

    private func pollStatusResponse(jobId: String?, generationId: String?) async throws -> BackendRawResponse {
        let cleanedUserId = userId.trimmed
        let cleanedLang = lang.trimmed
        var queryItems: [URLQueryItem] = []
        let path: String

        if let jobId, !jobId.isEmpty {
            path = "services/status"
            if !cleanedUserId.isEmpty {
                queryItems.append(URLQueryItem(name: "userId", value: cleanedUserId))
            }
            queryItems.append(URLQueryItem(name: "jobId", value: jobId))
            if !cleanedLang.isEmpty {
                queryItems.append(URLQueryItem(name: "lang", value: cleanedLang))
            }
        } else if let generationId, !generationId.isEmpty {
            path = "services/status/queue"
            if !cleanedUserId.isEmpty {
                queryItems.append(URLQueryItem(name: "userId", value: cleanedUserId))
            }
            queryItems.append(URLQueryItem(name: "generationId", value: generationId))
        } else {
            throw BackendTestServiceError.invalidEndpointURL
        }

        return try await service.sendRequest(
            baseURLString: baseURLString.trimmed,
            bearerToken: bearerToken.trimmed,
            method: .get,
            path: path,
            queryItems: queryItems,
            bodyType: .none
        )
    }

    private func makePostResultSnapshot(
        response: BackendRawResponse,
        pollAttempt: Int,
        fallbackMessage: String?
    ) -> EndpointPostResult {
        let parsed = parsePostResponse(data: response.data)
        let statusUpper = parsed.backendStatus?.uppercased()
        let pendingStatuses: Set<String> = ["NEW", "IN_PROGRESS", "IN_QUEUE", "QUEUED", "PROCESSING", "PENDING", "RUNNING", "STARTED"]
        let successStatuses: Set<String> = ["COMPLETED", "SUCCESS", "DONE", "FINISHED", "READY"]
        let failedStatuses: Set<String> = ["FAILED", "ERROR", "CANCELED", "CANCELLED", "REJECTED", "TIMEOUT"]

        let isPending = statusUpper.map { pendingStatuses.contains($0) } ?? false
        let isSuccessStatus = statusUpper.map { successStatuses.contains($0) } ?? false
        let isFailedStatus = statusUpper.map { failedStatuses.contains($0) } ?? false
        let hasImageURLs = !parsed.imageURLs.isEmpty
        let hasIdentifiers = (parsed.jobId?.isEmpty == false) || (parsed.generationId?.isEmpty == false)
        let hasBackendError = parsed.errorFlag ?? false

        let shouldPoll = response.isSuccess
            && !hasBackendError
            && !isFailedStatus
            && (isPending || (!isSuccessStatus && !hasImageURLs && hasIdentifiers))

        let state: EndpointPostState
        if !response.isSuccess || hasBackendError || isFailedStatus {
            state = .failure
        } else if shouldPoll {
            state = .polling
        } else {
            state = .success
        }

        let message: String = {
            if let explicit = fallbackMessage?.trimmed, !explicit.isEmpty, state == .polling {
                return explicit
            }

            if let server = parsed.message?.trimmed, !server.isEmpty {
                return server
            }

            switch state {
            case .running:
                return "Запрос отправлен."
            case .polling:
                return "Поллинг каждую 1с. Ожидаем готовый результат."
            case .success:
                return hasImageURLs ? "Готово: backend вернул результат." : "Готово: backend ответил без ошибок."
            case .failure:
                return "Ошибка выполнения endpoint."
            case .timeout:
                return "Превышено время ожидания результата."
            }
        }()

        return EndpointPostResult(
            state: state,
            httpCode: response.statusCode,
            backendStatus: parsed.backendStatus,
            message: message,
            jobId: parsed.jobId,
            generationId: parsed.generationId,
            imageURLs: parsed.imageURLs,
            fields: parsed.fields,
            rawJSON: parsed.rawJSON,
            pollAttempt: pollAttempt,
            shouldPoll: shouldPoll
        )
    }

    private func parsePostResponse(data: Data) -> ParsedPostResponse {
        let rawJSON = prettyJSONString(from: data)

        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return ParsedPostResponse(
                errorFlag: nil,
                message: nil,
                backendStatus: nil,
                jobId: nil,
                generationId: nil,
                imageURLs: [],
                fields: [],
                rawJSON: rawJSON
            )
        }

        guard let rootObject = root as? [String: Any] else {
            return ParsedPostResponse(
                errorFlag: nil,
                message: nil,
                backendStatus: nil,
                jobId: nil,
                generationId: nil,
                imageURLs: [],
                fields: [],
                rawJSON: rawJSON
            )
        }

        let dataNode = rootObject["data"]
        let dataObject = dataNode as? [String: Any]
        let errorFlag = parseBool(rootObject["error"])
        let message = stringify(rootObject["message"])
        let backendStatus = stringify(dataObject?["status"] ?? rootObject["status"])
        let jobId = stringify(dataObject?["jobId"] ?? rootObject["jobId"])
        let generationId = stringify(dataObject?["generationId"] ?? dataObject?["id"] ?? rootObject["generationId"])

        var fields: [EndpointObjectPreviewField] = []
        if let backendStatus {
            appendField("status", from: backendStatus, to: &fields)
        }
        if let jobId {
            appendField("jobId", from: jobId, to: &fields)
        }
        if let generationId {
            appendField("generationId", from: generationId, to: &fields)
        }
        if let dataObject {
            let priorityKeys = ["id", "templateId", "resultUrl", "preview", "seconds", "startedAt", "finishedAt"]
            for key in priorityKeys {
                appendField(key, from: dataObject[key], to: &fields)
            }
            if fields.count < 8 {
                for key in dataObject.keys.sorted() where !priorityKeys.contains(key) {
                    appendField(key, from: dataObject[key], to: &fields)
                    if fields.count >= 8 {
                        break
                    }
                }
            }
        } else if let dataArray = dataNode as? [Any] {
            appendField("dataCount", from: dataArray.count, to: &fields)
            if let first = dataArray.first as? [String: Any] {
                appendField("first.id", from: first["id"], to: &fields)
                appendField("first.status", from: first["status"], to: &fields)
                appendField("first.resultUrl", from: first["resultUrl"], to: &fields)
            }
        }

        let imageURLs = extractImageURLs(from: rootObject)

        return ParsedPostResponse(
            errorFlag: errorFlag,
            message: message,
            backendStatus: backendStatus,
            jobId: jobId,
            generationId: generationId,
            imageURLs: imageURLs,
            fields: fields,
            rawJSON: rawJSON
        )
    }

    private func parseBool(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let intValue = value as? Int {
            return intValue != 0
        }
        if let stringValue = value as? String {
            let normalized = stringValue.trimmed.lowercased()
            if normalized == "true" || normalized == "1" {
                return true
            }
            if normalized == "false" || normalized == "0" {
                return false
            }
        }
        return nil
    }

    private func prettyJSONString(from data: Data) -> String? {
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        if let utf8 = String(data: data, encoding: .utf8) {
            let trimmed = utf8.trimmed
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }

    private func extractImageURLs(from object: [String: Any]) -> [URL] {
        var candidates: [(url: String, key: String?)] = []
        collectURLCandidates(from: object, keyHint: nil, into: &candidates)

        var filtered: [URL] = []
        var seen: Set<String> = []

        for candidate in candidates {
            guard isLikelyImageURL(candidate.url, keyHint: candidate.key), let url = URL(string: candidate.url) else {
                continue
            }
            if seen.contains(url.absoluteString) {
                continue
            }
            seen.insert(url.absoluteString)
            filtered.append(url)
        }

        if !filtered.isEmpty {
            return filtered
        }

        // Fallback: если backend вернул URL без расширения/подсказки ключа.
        var fallback: [URL] = []
        for candidate in candidates {
            guard let url = URL(string: candidate.url) else { continue }
            if seen.contains(url.absoluteString) {
                continue
            }
            seen.insert(url.absoluteString)
            fallback.append(url)
        }
        return fallback
    }

    private func collectURLCandidates(from value: Any, keyHint: String?, into result: inout [(url: String, key: String?)]) {
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmed
            let lowercased = trimmed.lowercased()
            if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
                result.append((url: trimmed, key: keyHint))
            }
            return
        }

        if let dictionary = value as? [String: Any] {
            for (key, nested) in dictionary {
                collectURLCandidates(from: nested, keyHint: key, into: &result)
            }
            return
        }

        if let array = value as? [Any] {
            for nested in array {
                collectURLCandidates(from: nested, keyHint: keyHint, into: &result)
            }
        }
    }

    private func isLikelyImageURL(_ value: String, keyHint: String?) -> Bool {
        let lowerValue = value.lowercased()
        let key = (keyHint ?? "").lowercased()
        let keyHints = ["preview", "photo", "image", "avatar", "watermark", "result"]
        if keyHints.contains(where: { key.contains($0) }) {
            return true
        }

        let imageExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".heic", ".heif", ".avif"]
        return imageExtensions.contains(where: { lowerValue.contains($0) })
    }

    private func makeObjectPreview(endpointID: String, data: Data) -> EndpointObjectPreview {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return EndpointObjectPreview(
                totalCount: 0,
                shownCount: 0,
                items: [],
                note: "Не удалось прочитать JSON ответа."
            )
        }

        let payload: Any
        if let rootObject = root as? [String: Any], let dataValue = rootObject["data"] {
            payload = dataValue
        } else {
            payload = root
        }

        let rawItems: [Any]
        if let array = payload as? [Any] {
            rawItems = array
        } else if let object = payload as? [String: Any] {
            rawItems = [object]
        } else {
            rawItems = []
        }

        let totalCount = rawItems.count
        let shownItems = Array(rawItems.prefix(120))
        let previewItems = shownItems.enumerated().map { index, raw in
            makeObjectPreviewItem(endpointID: endpointID, index: index, raw: raw)
        }

        let note: String? = {
            if totalCount == 0 {
                switch endpointID {
                case "avatar/list":
                    return "avatar/list вернул 0 объектов. Для этого userId пока нет готовых аватаров."
                case "photo/popular":
                    return "photo/popular вернул 0 объектов. Для templateId используйте GET photo/styles (templates[].id), GET photo/txt2imgStyles или GET photo/img2imgStyles."
                default:
                    return "Список пуст. Backend вернул 0 объектов."
                }
            }
            if totalCount > shownItems.count {
                return "Показано \(shownItems.count) из \(totalCount)."
            }
            return "Получено объектов: \(totalCount)."
        }()

        return EndpointObjectPreview(
            totalCount: totalCount,
            shownCount: shownItems.count,
            items: previewItems,
            note: note
        )
    }

    private func makeObjectPreviewItem(endpointID: String, index: Int, raw: Any) -> EndpointObjectPreviewItem {
        guard let object = raw as? [String: Any] else {
            let fallback = stringify(raw) ?? "—"
            return EndpointObjectPreviewItem(
                id: "raw-\(endpointID)-\(index)",
                objectID: nil,
                title: "Object #\(index + 1)",
                subtitle: nil,
                fields: [EndpointObjectPreviewField(key: "value", value: fallback)]
            )
        }

        switch endpointID {
        case "avatar/list":
            return makeAvatarPreviewItem(endpointID: endpointID, index: index, object: object)
        case "photo/styles", "photo/popular", "photo/txt2imgStyles", "photo/img2imgStyles":
            return makeStylePreviewItem(endpointID: endpointID, index: index, object: object)
        case "photo/editorExamples":
            return makeEditorExamplePreviewItem(endpointID: endpointID, index: index, object: object)
        default:
            return makeGenericPreviewItem(endpointID: endpointID, index: index, object: object)
        }
    }

    private func makeAvatarPreviewItem(endpointID: String, index: Int, object: [String: Any]) -> EndpointObjectPreviewItem {
        let objectID = firstNonEmptyString(in: object, keys: ["id"])
        let title = firstNonEmptyString(in: object, keys: ["title"]) ?? "Avatar #\(index + 1)"
        let subtitle = firstNonEmptyString(in: object, keys: ["gender"])

        var fields: [EndpointObjectPreviewField] = []
        appendField("gender", from: object["gender"], to: &fields)
        appendField("isActive", from: object["isActive"], to: &fields)
        appendField("preview", from: object["preview"], to: &fields)

        return EndpointObjectPreviewItem(
            id: "avatar-\(endpointID)-\(index)-\(objectID ?? "na")",
            objectID: objectID,
            title: title,
            subtitle: subtitle,
            fields: fields
        )
    }

    private func makeStylePreviewItem(endpointID: String, index: Int, object: [String: Any]) -> EndpointObjectPreviewItem {
        let objectID = preferredID(in: object)
        let title = firstNonEmptyString(in: object, keys: ["title", "subTitle", "description"]) ?? "Style #\(index + 1)"
        let subtitle = firstNonEmptyString(in: object, keys: ["description", "subTitle", "code"])

        var fields: [EndpointObjectPreviewField] = []
        appendField("code", from: object["code"], to: &fields)
        appendField("gender", from: object["gender"], to: &fields)
        appendField("priceTokens", from: object["priceTokens"], to: &fields)
        appendField("totalTemplates", from: object["totalTemplates"], to: &fields)
        appendField("totalUsed", from: object["totalUsed"], to: &fields)
        appendField("isPackage", from: object["isPackage"], to: &fields)
        appendField("isCouple", from: object["isCouple"], to: &fields)
        appendField("isNew", from: object["isNew"], to: &fields)
        appendField("isExclusive", from: object["isExclusive"], to: &fields)
        appendField("preview", from: object["preview"], to: &fields)

        if let templates = object["templates"] as? [Any] {
            appendField("templatesCount", from: templates.count, to: &fields)
            if
                let firstTemplate = templates.first as? [String: Any],
                let firstTemplateID = stringify(firstTemplate["id"]) {
                appendField("firstTemplateId", from: firstTemplateID, to: &fields)
            }
            if let firstTemplate = templates.first as? [String: Any] {
                appendField("firstTemplatePreview", from: firstTemplate["preview"], to: &fields)
            }
        }

        return EndpointObjectPreviewItem(
            id: "style-\(endpointID)-\(index)-\(objectID ?? "na")",
            objectID: objectID,
            title: title,
            subtitle: subtitle,
            fields: fields
        )
    }

    private func makeEditorExamplePreviewItem(endpointID: String, index: Int, object: [String: Any]) -> EndpointObjectPreviewItem {
        let objectID = preferredID(in: object)
        let title = firstNonEmptyString(in: object, keys: ["prompt", "modelType"]) ?? "Editor example #\(index + 1)"

        var fields: [EndpointObjectPreviewField] = []
        appendField("modelType", from: object["modelType"], to: &fields)
        appendField("prompt", from: object["prompt"], to: &fields)
        appendField("resultPhoto", from: object["resultPhoto"], to: &fields)

        if let inputPhotos = object["inputPhotos"] as? [Any] {
            appendField("inputPhotosCount", from: inputPhotos.count, to: &fields)
            if let first = inputPhotos.first {
                appendField("firstInputPhoto", from: first, to: &fields)
            }
        }

        return EndpointObjectPreviewItem(
            id: "editor-\(endpointID)-\(index)-\(objectID ?? "na")",
            objectID: objectID,
            title: title,
            subtitle: nil,
            fields: fields
        )
    }

    private func makeGenericPreviewItem(endpointID: String, index: Int, object: [String: Any]) -> EndpointObjectPreviewItem {
        let objectID = preferredID(in: object)
        let title = firstNonEmptyString(in: object, keys: ["title", "name", "prompt", "description"]) ?? "Object #\(index + 1)"

        var fields: [EndpointObjectPreviewField] = []
        for key in object.keys.sorted().prefix(8) {
            appendField(key, from: object[key], to: &fields)
        }

        return EndpointObjectPreviewItem(
            id: "generic-\(endpointID)-\(index)-\(objectID ?? "na")",
            objectID: objectID,
            title: title,
            subtitle: nil,
            fields: fields
        )
    }

    private func preferredID(in object: [String: Any]) -> String? {
        firstNonEmptyString(in: object, keys: ["id", "templateId", "styleId", "jobId", "generationId", "code"])
    }

    private func firstNonEmptyString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = stringify(object[key]), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func appendField(_ key: String, from value: Any?, to fields: inout [EndpointObjectPreviewField]) {
        guard let rendered = stringify(value), !rendered.isEmpty else { return }
        fields.append(EndpointObjectPreviewField(key: key, value: rendered))
    }

    private func stringify(_ value: Any?) -> String? {
        guard let value else { return nil }

        if value is NSNull {
            return nil
        }

        if let stringValue = value as? String {
            let trimmed = stringValue.trimmed
            return trimmed.isEmpty ? nil : trimmed
        }

        if let intValue = value as? Int {
            return String(intValue)
        }

        if let doubleValue = value as? Double {
            return String(doubleValue)
        }

        if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        }

        if let array = value as? [Any] {
            return "[\(array.count)]"
        }

        if let dictionary = value as? [String: Any] {
            return "{\(dictionary.count) keys}"
        }

        return String(describing: value)
    }

    private func hydrateUserState(from data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = object["data"] as? [String: Any]
        else {
            return
        }

        if let directUserId = payload.stringValue(forKey: "userId"), !directUserId.isEmpty {
            userId = directUserId
        } else if
            let profile = payload["profile"] as? [String: Any],
            let profileUserId = profile.stringValue(forKey: "userId"),
            !profileUserId.isEmpty {
            userId = profileUserId
        }

        let availableTopLevel = payload.intValue(forKey: "availableGenerations")
        let availableFromStat: Int = {
            guard let stat = payload["stat"] as? [String: Any] else { return 0 }
            return stat.intValue(forKey: "availableGenerations") ?? 0
        }()

        let available = max(availableTopLevel ?? 0, availableFromStat)
        availableGenerationsText = String(available)

        if let isActivePlan = payload.boolValue(forKey: "isActivePlan") {
            activePlanText = isActivePlan ? "true" : "false"
        } else if let isActiveSub = payload.boolValue(forKey: "isActiveSubscription") {
            activePlanText = isActiveSub ? "true" : "false"
        }
    }

    private func appendResponseLog(title: String, response: BackendRawResponse) {
        if response.statusCode == 404 {
            let serverMessage = extractServerMessage(from: response.data)
            if serverMessage.isEmpty {
                statusLine = "\(title) -> HTTP 404 (маршрут не найден на текущем backend)"
            } else {
                statusLine = "\(title) -> HTTP 404 (\(serverMessage))"
            }
            return
        }

        statusLine = "\(title) -> HTTP \(response.statusCode)"
    }

    private func appendErrorLog(title: String, error: Error) {
        statusLine = "\(title) -> error"
    }

    private func appendValidationError(_ message: String) {
        statusLine = message
    }

    private func extractServerMessage(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String
        else {
            return ""
        }

        return message.trimmed
    }

    private func syncUserIdToPhotoFields() {
        let cleanedUserId = userId.trimmed

        for endpoint in photoEndpoints where endpoint.parameters.contains(where: { $0.key == "userId" }) {
            var endpointValues = photoTextValues[endpoint.id] ?? [:]
            endpointValues["userId"] = cleanedUserId
            photoTextValues[endpoint.id] = endpointValues
        }
    }

    private func maxUploadCount(for endpointID: String) -> Int {
        switch endpointID {
        case "photo/generate/autoRef":
            return 2
        case "photo/banana/generate", "photo/banana/templated/generate":
            return 4
        case "photo/generateInStyle":
            return 10
        default:
            return 1
        }
    }

    private func applyUploadedURLs(endpointID: String, urls: [String]) {
        switch endpointID {
        case "photo/generate/autoRef":
            var values = photoTextValues[endpointID] ?? [:]
            if let first = urls.first {
                values["referenceImageUrl"] = first
            }
            if urls.count > 1 {
                values["personImageUrl"] = urls[1]
            }
            photoTextValues[endpointID] = values
            statusLine = "AutoRef: подставлено \(min(2, urls.count)) URL из upload"

        case "photo/banana/generate", "photo/banana/templated/generate":
            let limited = Array(urls.prefix(4))
            var endpointArrays = photoArrayValues[endpointID] ?? [:]
            endpointArrays["imageUrl[]"] = limited
            photoArrayValues[endpointID] = endpointArrays
            statusLine = "\(endpointID): подставлено \(limited.count) URL из upload"

        case "photo/generateInStyle":
            let limited = Array(urls.prefix(10))
            var endpointArrays = photoArrayValues[endpointID] ?? [:]
            endpointArrays["images[]"] = limited
            photoArrayValues[endpointID] = endpointArrays
            statusLine = "photo/generateInStyle: подставлено \(limited.count) URL в images[]"

        default:
            statusLine = "Upload completed, но endpoint \(endpointID) не поддерживает автоподстановку URL"
        }
    }

    private func extractURLs(from data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        var result: [String] = []
        collectURLs(from: object, into: &result)
        return result
    }

    private func collectURLs(from value: Any, into result: inout [String]) {
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmed
            let lowercased = trimmed.lowercased()
            if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
                result.append(trimmed)
            }
            return
        }

        if let dictionary = value as? [String: Any] {
            for (_, nested) in dictionary {
                collectURLs(from: nested, into: &result)
            }
            return
        }

        if let array = value as? [Any] {
            for nested in array {
                collectURLs(from: nested, into: &result)
            }
        }
    }
}

struct EndpointObjectPreview {
    let totalCount: Int
    let shownCount: Int
    let items: [EndpointObjectPreviewItem]
    let note: String?
}

struct EndpointObjectPreviewItem: Identifiable {
    let id: String
    let objectID: String?
    let title: String
    let subtitle: String?
    let fields: [EndpointObjectPreviewField]
}

struct EndpointObjectPreviewField: Identifiable {
    let key: String
    let value: String

    var id: String {
        "\(key)-\(value)"
    }
}

enum EndpointPostState {
    case running
    case polling
    case success
    case failure
    case timeout
}

struct EndpointPostResult {
    let state: EndpointPostState
    let httpCode: Int?
    let backendStatus: String?
    let message: String
    let jobId: String?
    let generationId: String?
    let imageURLs: [URL]
    let fields: [EndpointObjectPreviewField]
    let rawJSON: String?
    let pollAttempt: Int
    let shouldPoll: Bool
}

private struct ParsedPostResponse {
    let errorFlag: Bool?
    let message: String?
    let backendStatus: String?
    let jobId: String?
    let generationId: String?
    let imageURLs: [URL]
    let fields: [EndpointObjectPreviewField]
    let rawJSON: String?
}

struct ParameterPrefillExplanation {
    let value: String
    let source: String
    let why: String
    let alternatives: String
}

private enum UserIdStorage {
    static let key = "BackendTestLab.userId"

    static func loadOrCreate() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            return existing
        }

        let newValue = "ios-test-user-\(UUID().uuidString.prefix(12))"
        defaults.set(newValue, forKey: key)
        return newValue
    }

    static func save(_ userId: String) {
        let cleaned = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        UserDefaults.standard.set(cleaned, forKey: key)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Dictionary where Key == String, Value == Any {
    func stringValue(forKey key: String) -> String? {
        if let value = self[key] as? String {
            return value.trimmed
        }
        if let value = self[key] as? Int {
            return String(value)
        }
        if let value = self[key] as? Double {
            return String(value)
        }
        return nil
    }

    func intValue(forKey key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? String, let intValue = Int(value) {
            return intValue
        }
        if let value = self[key] as? Double {
            return Int(value)
        }
        return nil
    }

    func boolValue(forKey key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? Int {
            return value != 0
        }
        if let value = self[key] as? String {
            switch value.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
