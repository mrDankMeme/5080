//
//  ContentView.swift
//  APITests
//
//  Created by Niiaz Khasanov on 4/9/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = BackendTestLabViewModel()
    @State private var collapsedEndpointIDs: Set<String> = []

    private let actionColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerView
                    connectionCard
                    authCard
                    balanceCard
                    photoCard
                }
                .padding(14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Backend Test Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Request in progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Status: \(viewModel.statusLine)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                metricPill(title: "userId", value: viewModel.userId)
                metricPill(title: "tokens", value: viewModel.availableGenerationsText)
                metricPill(title: "active plan", value: viewModel.activePlanText)
            }
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var connectionCard: some View {
        LabCard(title: "Connection") {
            VStack(spacing: 10) {
                LabLabeledField(label: "base URL") {
                    TextField("https://aiapp.fotobudka.online/api/v1/", text: $viewModel.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LabLabeledField(label: "bearer token") {
                    TextField("Bearer token", text: $viewModel.bearerToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                HStack(spacing: 8) {
                    LabLabeledField(label: "source") {
                        TextField("source", text: $viewModel.source)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    LabLabeledField(label: "lang") {
                        TextField("ru", text: $viewModel.lang)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .frame(width: 90)
                }
            }
        }
    }

    private var authCard: some View {
        LabCard(title: "Auth") {
            VStack(alignment: .leading, spacing: 10) {
                LabLabeledField(label: "userId") {
                    TextField("ios-test-user-...", text: $viewModel.userId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Text("Создайте userId один раз и используйте его дальше. Он сохраняется между запусками приложения.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LabLabeledField(label: "gender") {
                    Picker("gender", selection: $viewModel.gender) {
                        Text("f").tag("f")
                        Text("m").tag("m")
                    }
                    .pickerStyle(.segmented)
                }

                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionButton(title: "POST user/login") {
                        viewModel.login()
                    }

                    ActionButton(title: "GET user/profile") {
                        viewModel.fetchProfile()
                    }
                }
            }
        }
    }

    private var balanceCard: some View {
        LabCard(title: "Balance Tools") {
            VStack(alignment: .leading, spacing: 10) {
                LabLabeledField(label: "productId") {
                    TextField("10", text: $viewModel.productId)
                        .keyboardType(.numberPad)
                }

                LazyVGrid(columns: actionColumns, spacing: 8) {
                    ActionButton(title: "POST user/setFreeGenerations") {
                        viewModel.setFreeGenerations()
                    }

                    ActionButton(title: "POST user/addGenerations") {
                        viewModel.addGenerations()
                    }

                    ActionButton(title: "POST user/collectTokens") {
                        viewModel.collectTokens()
                    }

                    ActionButton(title: "GET user/availableBonuses") {
                        viewModel.availableBonuses()
                    }
                }
            }
        }
    }

    private var photoCard: some View {
        LabCard(title: "Photo") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.photoEndpoints) { endpoint in
                    endpointCard(endpoint)
                }
            }
        }
    }

    private func endpointCard(_ endpoint: PhotoEndpointDefinition) -> some View {
        let isCollapsed = collapsedEndpointIDs.contains(endpoint.id)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                if isCollapsed {
                    collapsedEndpointIDs.remove(endpoint.id)
                } else {
                    collapsedEndpointIDs.insert(endpoint.id)
                }
            } label: {
                HStack(spacing: 8) {
                    Text("\(endpoint.method.rawValue) \(endpoint.name)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                HStack(alignment: .center, spacing: 8) {
                    Text(endpoint.method.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(endpoint.method == .get ? Color.green : Color.orange)
                        .clipShape(Capsule())

                    Text(endpoint.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                endpointDependencyBlock(endpoint)
                endpointGuideBlock(endpoint)
                endpointURLUploadBridge(endpoint)

                VStack(spacing: 10) {
                    ForEach(endpoint.parameters) { parameter in
                        parameterInput(parameter, endpointID: endpoint.id)
                    }
                }

                ActionButton(title: "Run \(endpoint.method.rawValue) \(endpoint.path)") {
                    viewModel.executePhotoEndpoint(endpointID: endpoint.id)
                }

                if endpoint.method == .post {
                    endpointPostResultBlock(endpointID: endpoint.id)
                }

                if endpoint.method == .get, viewModel.supportsObjectPreview(endpointID: endpoint.id) {
                    endpointObjectsBlock(endpointID: endpoint.id)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func endpointGuideBlock(_ endpoint: PhotoEndpointDefinition) -> some View {
        let guide = viewModel.endpointGuide(for: endpoint.id)

        return VStack(alignment: .leading, spacing: 4) {
            Text("Что делает: \(guide.whatItDoes)")
            Text("Зачем нужен: \(guide.whyItIsNeeded)")
            Text("Параметры:")
                .font(.caption.weight(.semibold))
                .padding(.top, 2)
            ForEach(endpoint.parameters) { parameter in
                Text("• \(parameter.required ? "\(parameter.title) *" : parameter.title): \(viewModel.parameterGuide(for: parameter.key))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func endpointURLUploadBridge(_ endpoint: PhotoEndpointDefinition) -> some View {
        switch endpoint.id {
        case "photo/generate/autoRef":
            URLFromGalleryUploadField(
                title: "Фото из галереи для autoRef",
                subtitle: "Выбери ровно 2 фото. После upload они подставятся в referenceImageUrl и personImageUrl.",
                minSelectionCount: 2,
                maxSelectionCount: 2,
                uploadButtonTitle: "Upload 2 photo(s) and fill URL fields"
            ) { files in
                viewModel.uploadAndApplyImageURLs(endpointID: endpoint.id, files: files)
            }

        case "photo/banana/generate", "photo/banana/templated/generate":
            URLFromGalleryUploadField(
                title: "Фото из галереи для imageUrl[]",
                subtitle: "Можно выбрать от 1 до 4 фото. После upload ссылки заполнят imageUrl[].",
                minSelectionCount: 1,
                maxSelectionCount: 4,
                uploadButtonTitle: "Upload selected photo(s) and fill imageUrl[]"
            ) { files in
                viewModel.uploadAndApplyImageURLs(endpointID: endpoint.id, files: files)
            }

        case "photo/generateInStyle":
            URLFromGalleryUploadField(
                title: "Фото из галереи для images[]",
                subtitle: "Выбери 1 или больше фото. После upload ссылки автоматически подставятся в images[].",
                minSelectionCount: 1,
                maxSelectionCount: 10,
                uploadButtonTitle: "Upload photo(s) and fill images[]"
            ) { files in
                viewModel.uploadAndApplyImageURLs(endpointID: endpoint.id, files: files)
            }

        default:
            EmptyView()
        }
    }

    private func endpointDependencyBlock(_ endpoint: PhotoEndpointDefinition) -> some View {
        let hints = viewModel.dependencyHints(for: endpoint.id)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(hints) { hint in
                HStack(alignment: .top, spacing: 8) {
                    Text(hint.kind == .providesData ? "Связь: результат используется дальше" : "Связь: нужны входные данные")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(hint.kind == .providesData ? Color.blue : Color.orange)
                    Spacer(minLength: 0)
                }

                Text(hint.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(hint.kind == .providesData ? Color.blue.opacity(0.14) : Color.orange.opacity(0.14))
                    )
            }
        }
    }

    private func endpointObjectsBlock(endpointID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Объекты из ответа")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let preview = viewModel.objectPreview(for: endpointID) {
                if let note = preview.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if preview.items.isEmpty {
                    Text("Пока нет объектов. Нажми Run GET.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(preview.items) { item in
                        endpointObjectRow(item)
                    }
                }
            } else {
                Text("После Run GET здесь появится коллекция объектов.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func endpointPostResultBlock(endpointID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Результат POST")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if let result = viewModel.postResult(for: endpointID) {
                HStack(spacing: 8) {
                    Text(postStateTitle(result.state))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(postStateColor(result.state))
                        .clipShape(Capsule())

                    if let code = result.httpCode {
                        Text("HTTP \(code)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let backendStatus = result.backendStatus, !backendStatus.isEmpty {
                        Text("status: \(backendStatus)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(result.message)
                    .font(.caption2)
                    .foregroundStyle(.primary)

                if result.pollAttempt > 0, result.state == .polling {
                    Text("Попытка поллинга: \(result.pollAttempt)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let jobId = result.jobId, !jobId.isEmpty {
                    HStack(spacing: 8) {
                        Text("jobId: \(jobId)")
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("Copy jobId") {
                            UIPasteboard.general.string = jobId
                        }
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                if let generationId = result.generationId, !generationId.isEmpty {
                    HStack(spacing: 8) {
                        Text("generationId: \(generationId)")
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("Copy generationId") {
                            UIPasteboard.general.string = generationId
                        }
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                if !result.imageURLs.isEmpty {
                    endpointObjectImages(result.imageURLs)
                }

                ForEach(result.fields) { field in
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(field.key):")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(field.value)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }

                if result.state == .failure, let rawJSON = result.rawJSON, !rawJSON.isEmpty {
                    Text(rawJSON)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
            } else {
                Text("После Run POST здесь появится статус, результат или ошибка. Для асинхронных задач включается автополлинг 1с.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func postStateTitle(_ state: EndpointPostState) -> String {
        switch state {
        case .running:
            return "ОТПРАВЛЕНО"
        case .polling:
            return "ПОЛЛИНГ 1С"
        case .success:
            return "ГОТОВО"
        case .failure:
            return "ОШИБКА"
        case .timeout:
            return "ТАЙМАУТ"
        }
    }

    private func postStateColor(_ state: EndpointPostState) -> Color {
        switch state {
        case .running:
            return .gray
        case .polling:
            return .orange
        case .success:
            return .green
        case .failure:
            return .red
        case .timeout:
            return .purple
        }
    }

    private func endpointObjectRow(_ item: EndpointObjectPreviewItem) -> some View {
        let imageURLs = endpointObjectImageURLs(item)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let objectID = item.objectID, !objectID.isEmpty {
                    Button("Copy ID") {
                        UIPasteboard.general.string = objectID
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }

            if let objectID = item.objectID, !objectID.isEmpty {
                Text("id: \(objectID)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let subtitle = item.subtitle, !subtitle.isEmpty, subtitle != item.title {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !imageURLs.isEmpty {
                endpointObjectImages(imageURLs)
            }

            ForEach(item.fields) { field in
                HStack(alignment: .top, spacing: 4) {
                    Text("\(field.key):")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(field.value)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func endpointObjectImages(_ urls: [URL]) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            Text("Примеры картинок:")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(urls.prefix(4)), id: \.absoluteString) { url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color(.tertiarySystemFill)
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            @unknown default:
                                Color(.tertiarySystemFill)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    private func endpointObjectImageURLs(_ item: EndpointObjectPreviewItem) -> [URL] {
        var result: [URL] = []
        var seen: Set<String> = []

        for field in item.fields {
            guard looksLikeImageURL(field.value, key: field.key), let url = URL(string: field.value) else {
                continue
            }

            let key = url.absoluteString
            if seen.contains(key) {
                continue
            }

            seen.insert(key)
            result.append(url)
        }

        return result
    }

    private func looksLikeImageURL(_ value: String, key: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else {
            return false
        }

        let keyLower = key.lowercased()
        let imageKeyHints = ["preview", "photo", "image", "avatar", "watermark", "result"]
        if imageKeyHints.contains(where: { keyLower.contains($0) }) {
            return true
        }

        let imageExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".heic", ".heif", ".avif"]
        return imageExtensions.contains(where: { lower.contains($0) })
    }

    @ViewBuilder
    private func parameterInput(_ parameter: EndpointParameter, endpointID: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch parameter.kind {
            case .file:
                let maxFiles = fileSelectionLimit(endpointID: endpointID, parameterKey: parameter.key)
                PhotoSelectionField(
                    title: fieldTitle(parameter),
                    maxSelectionCount: maxFiles,
                    files: viewModel.files(endpointID: endpointID, key: parameter.key),
                    onAddFiles: { newFiles in
                        if maxFiles <= 1 {
                            viewModel.setFiles(Array(newFiles.prefix(1)), endpointID: endpointID, key: parameter.key)
                        } else {
                            var current = viewModel.files(endpointID: endpointID, key: parameter.key)
                            current.append(contentsOf: newFiles)
                            viewModel.setFiles(Array(current.prefix(maxFiles)), endpointID: endpointID, key: parameter.key)
                        }
                    },
                    onRemoveFile: { id in
                        viewModel.removeFile(endpointID: endpointID, key: parameter.key, id: id)
                    },
                    onClear: {
                        viewModel.setFiles([], endpointID: endpointID, key: parameter.key)
                    }
                )

            case .stringArray:
                ArrayParameterField(
                    title: fieldTitle(parameter),
                    placeholder: parameter.placeholder,
                    values: viewModel.valuesForArray(endpointID: endpointID, key: parameter.key),
                    onUpdate: { index, value in
                        viewModel.updateArrayValue(endpointID: endpointID, key: parameter.key, index: index, value: value)
                    },
                    onAdd: {
                        viewModel.addArrayValue(endpointID: endpointID, key: parameter.key)
                    },
                    onRemove: { index in
                        viewModel.removeArrayValue(endpointID: endpointID, key: parameter.key, index: index)
                    }
                )

            case .enumeration(let options):
                EnumOptionsField(
                    title: fieldTitle(parameter),
                    options: options,
                    selectedValue: viewModel.bindingForText(endpointID: endpointID, key: parameter.key),
                    allowsEmptyValue: !parameter.required
                )

            case .text, .integer:
                if parameter.key == "userId" {
                    LabLabeledField(label: fieldTitle(parameter)) {
                        Text(viewModel.userId)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    LabLabeledField(label: fieldTitle(parameter)) {
                        TextField(parameter.placeholder, text: viewModel.bindingForText(endpointID: endpointID, key: parameter.key), axis: parameter.key == "prompt" ? .vertical : .horizontal)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(parameter.kind.isInteger ? .numberPad : .default)
                            .lineLimit(parameter.key == "prompt" ? 3 : 1)
                    }
                }
            }

            if let banner = attachmentLimitBanner(parameter: parameter, endpointID: endpointID) {
                attachmentLimitBannerView(banner)
            }

            if let note = parameterNote(parameter, endpointID: endpointID) {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }

            if let prefill = viewModel.prefillExplanation(for: parameter, endpointID: endpointID) {
                parameterPrefillExplanation(prefill)
            }
        }
    }

    private func fieldTitle(_ parameter: EndpointParameter) -> String {
        parameter.required ? "\(parameter.title) *" : parameter.title
    }

    private func parameterNote(_ parameter: EndpointParameter, endpointID: String) -> String? {
        if parameter.key == "userId" {
            return "Автоматически берется из блока Auth."
        }

        if let note = parameter.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return note
        }

        let locationText: String = {
            switch parameter.location {
            case .query:
                return "Query"
            case .body:
                return "Body"
            }
        }()

        let typeText: String = {
            switch parameter.kind {
            case .text:
                return "string"
            case .integer:
                return "integer"
            case .file:
                return "file"
            case .stringArray:
                return "array[string]"
            case .enumeration:
                return "enum[string]"
            }
        }()

        return "\(locationText) param, type: \(typeText). \(viewModel.parameterGuide(for: parameter.key))"
    }

    private func attachmentLimitBanner(parameter: EndpointParameter, endpointID: String) -> AttachmentLimitBanner? {
        switch (endpointID, parameter.key) {
        case ("photo/generate/ref", "photo"),
             ("photo/generate/img2imgBasic", "photo"),
             ("photo/generate/styleTransfer", "photo"),
             ("photo/generate/ghibli", "photo"),
             ("photo/generate/animation", "file"),
             ("photo/generate/upscale", "image"),
             ("creator/img2img", "photo"),
             ("creator/img2imgRef", "photo"),
             ("effects/generate", "photo"),
             ("fitting/generate", "photo"),
             ("fitting/generate", "mask"),
             ("scenarios/generate", "photo"),
             ("styles/animate", "photo"),
             ("tools/grownUpChild", "photo"),
             ("tools/generate", "photo"):
            return AttachmentLimitBanner(
                title: "FILE PICKER: ТОЛЬКО 1 ФОТО",
                detail: "Этот endpoint принимает один файл изображения.",
                color: .red
            )
        case ("tools/futureChild", "photoMan"):
            return AttachmentLimitBanner(
                title: "FILE PICKER: НУЖНО 2 ФОТО (1/2)",
                detail: "Первое фото родителя. Второе нужно выбрать в поле photoWoman.",
                color: .red
            )
        case ("tools/futureChild", "photoWoman"):
            return AttachmentLimitBanner(
                title: "FILE PICKER: НУЖНО 2 ФОТО (2/2)",
                detail: "Второе фото родителя. Первое выбирается в поле photoMan.",
                color: .red
            )
        case ("fitting/generate", "clothingId"):
            return AttachmentLimitBanner(
                title: "УСЛОВИЕ: ЛИБО ID, ЛИБО ФОТО ОДЕЖДЫ",
                detail: "Передай clothingId или clothingImage. Обычно одно из двух.",
                color: .orange
            )
        case ("fitting/generate", "clothingImage"):
            return AttachmentLimitBanner(
                title: "УСЛОВИЕ: ЛИБО ФОТО, ЛИБО ID",
                detail: "Если передал clothingImage, clothingId обычно не передают.",
                color: .orange
            )
        case ("scenarios/generate", "mode"):
            return AttachmentLimitBanner(
                title: "УСЛОВИЕ: MODE ВЛИЯЕТ НА ПОЛЯ",
                detail: "mode=1: используй avatarId. mode=2: используй photo (+ обычно gender).",
                color: .blue
            )
        case ("styles/animate", "userPrompt"):
            return AttachmentLimitBanner(
                title: "ПОДСКАЗКА: PROMPT ИЛИ ШАБЛОН",
                detail: "При userPrompt обычно ставят isCustomPrompt=1, а animationId можно не передавать.",
                color: .teal
            )
        case ("photo/generate/autoRef", "referenceImageUrl"):
            return AttachmentLimitBanner(
                title: "URL: НУЖНО 2 ССЫЛКИ (1/2)",
                detail: "Это первая ссылка: `referenceImageUrl`.",
                color: .blue
            )
        case ("photo/generate/autoRef", "personImageUrl"):
            return AttachmentLimitBanner(
                title: "URL: НУЖНО 2 ССЫЛКИ (2/2)",
                detail: "Это вторая ссылка: `personImageUrl`.",
                color: .blue
            )
        case ("photo/banana/generate", "imageUrl[]"),
             ("photo/banana/templated/generate", "imageUrl[]"):
            return AttachmentLimitBanner(
                title: "URL: ОТ 1 ДО 4 ССЫЛОК",
                detail: "Можно выбрать фото из пикера и получить URL через upload-блок.",
                color: .orange
            )
        case ("photo/seedream", "imageUrls[]"),
             ("photo/seedream/templated", "imageUrls[]"):
            return AttachmentLimitBanner(
                title: "URL: ДО 10 ССЫЛОК",
                detail: "Если отправить больше 10, backend использует последние 10.",
                color: .purple
            )
        case ("photo/generateInStyle", "images[]"):
            return AttachmentLimitBanner(
                title: "URL: НЕСКОЛЬКО ССЫЛОК",
                detail: "Поле принимает массив URL. Можно выбрать фото в пикере, upload превратит их в ссылки и подставит в images[].",
                color: .teal
            )
        default:
            return nil
        }
    }

    private func attachmentLimitBannerView(_ banner: AttachmentLimitBanner) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(banner.title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(banner.color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(banner.detail)
                .font(.caption2.weight(.medium))
                .foregroundStyle(banner.color)
        }
        .padding(.top, 2)
    }

    private func fileSelectionLimit(endpointID: String, parameterKey: String) -> Int {
        switch (endpointID, parameterKey) {
        case ("photo/generate/ref", "photo"),
             ("photo/generate/img2imgBasic", "photo"),
             ("photo/generate/styleTransfer", "photo"),
             ("photo/generate/ghibli", "photo"),
             ("photo/generate/animation", "file"),
             ("photo/generate/upscale", "image"),
             ("creator/img2img", "photo"),
             ("creator/img2imgRef", "photo"),
             ("effects/generate", "photo"),
             ("fitting/generate", "photo"),
             ("fitting/generate", "mask"),
             ("fitting/generate", "clothingImage"),
             ("scenarios/generate", "photo"),
             ("styles/animate", "photo"),
             ("tools/futureChild", "photoMan"),
             ("tools/futureChild", "photoWoman"),
             ("tools/grownUpChild", "photo"),
             ("tools/generate", "photo"):
            return 1
        default:
            return 1
        }
    }

    private func parameterPrefillExplanation(_ explanation: ParameterPrefillExplanation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Почему уже заполнено")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.green.opacity(0.95))

            Text("Значение: \(explanation.value)")
            Text("Источник: \(explanation.source)")
            Text("Почему так: \(explanation.why)")
            Text("Какие ещё могут быть: \(explanation.alternatives)")
        }
        .font(.caption2)
        .foregroundStyle(.primary)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.14))
        )
    }
}

private struct AttachmentLimitBanner {
    let title: String
    let detail: String
    let color: Color
}

private struct LabCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LabLabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            content
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .contextMenu {
            Button("Copy button title") {
                UIPasteboard.general.string = title
            }
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.black.opacity(0.7) : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct EnumOptionsField: View {
    let title: String
    let options: [String]
    @Binding var selectedValue: String
    let allowsEmptyValue: Bool

    private var allOptions: [String] {
        allowsEmptyValue ? [""] + options : options
    }

    private let optionColumns = [GridItem(.adaptive(minimum: 82), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: optionColumns, alignment: .leading, spacing: 8) {
                ForEach(allOptions, id: \.self) { option in
                    let label = option.isEmpty ? "(none)" : option
                    let isSelected = selectedValue == option

                    Button {
                        selectedValue = option
                    } label: {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Color.black : Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }
}

private struct ArrayParameterField: View {
    let title: String
    let placeholder: String
    let values: [String]
    let onUpdate: (Int, String) -> Void
    let onAdd: () -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(spacing: 6) {
                    TextField(placeholder, text: Binding(
                        get: { value },
                        set: { onUpdate(index, $0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        onRemove(index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                onAdd()
            } label: {
                Label("Add value", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
    }
}

private struct PhotoSelectionField: View {
    let title: String
    let maxSelectionCount: Int
    let files: [PickedImageFile]
    let onAddFiles: ([PickedImageFile]) -> Void
    let onRemoveFile: (UUID) -> Void
    let onClear: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxSelectionCount,
                    matching: .images
                ) {
                    Label(maxSelectionCount == 1 ? "Pick image" : "Pick image(s)", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !files.isEmpty {
                    Button("Clear") {
                        onClear()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                Task {
                    await load(items: newItems)
                }
            }

            if let loadError, !loadError.isEmpty {
                Text(loadError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if files.isEmpty {
                Text("No images selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        HStack {
                            Text(file.fileName)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(file.sizeDescription)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Button {
                                onRemoveFile(file.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func load(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }

        await MainActor.run {
            isLoading = true
            loadError = nil
        }

        var loadedFiles: [PickedImageFile] = []

        for (index, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    continue
                }

                let contentType = item.supportedContentTypes.first
                let ext = contentType?.preferredFilenameExtension ?? "jpg"
                let mimeType = contentType?.preferredMIMEType ?? "image/jpeg"
                let file = PickedImageFile(
                    fileName: "image_\(index + 1).\(ext)",
                    mimeType: mimeType,
                    data: data
                )
                loadedFiles.append(file)
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                }
            }
        }

        await MainActor.run {
            isLoading = false
            pickerItems = []
            if !loadedFiles.isEmpty {
                onAddFiles(loadedFiles)
            }
        }
    }
}

private struct URLFromGalleryUploadField: View {
    let title: String
    let subtitle: String
    let minSelectionCount: Int
    let maxSelectionCount: Int
    let uploadButtonTitle: String
    let onUpload: ([PickedImageFile]) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedFiles: [PickedImageFile] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Выбрано: \(selectedFiles.count)/\(maxSelectionCount)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(selectedFiles.count >= minSelectionCount ? .green : .orange)

            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxSelectionCount,
                    matching: .images
                ) {
                    Label("Pick photo(s)", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !selectedFiles.isEmpty {
                    Button("Clear") {
                        selectedFiles = []
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                Task {
                    await load(items: newItems)
                }
            }

            if let loadError, !loadError.isEmpty {
                Text(loadError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if selectedFiles.isEmpty {
                Text("No photos selected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(selectedFiles) { file in
                        HStack(spacing: 6) {
                            Text("• \(file.fileName)")
                                .font(.caption2)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Button {
                                selectedFiles.removeAll { $0.id == file.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button(uploadButtonTitle) {
                onUpload(selectedFiles)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(selectedFiles.count < minSelectionCount)
            .contextMenu {
                Button("Copy button title") {
                    UIPasteboard.general.string = uploadButtonTitle
                }
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func load(items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }

        await MainActor.run {
            isLoading = true
            loadError = nil
        }

        var loadedFiles: [PickedImageFile] = []

        for (index, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                    continue
                }

                let contentType = item.supportedContentTypes.first
                let ext = contentType?.preferredFilenameExtension ?? "jpg"
                let mimeType = contentType?.preferredMIMEType ?? "image/jpeg"
                let file = PickedImageFile(
                    fileName: "picked_\(index + 1).\(ext)",
                    mimeType: mimeType,
                    data: data
                )
                loadedFiles.append(file)
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                }
            }
        }

        await MainActor.run {
            isLoading = false
            pickerItems = []
            if !loadedFiles.isEmpty {
                var merged = selectedFiles
                merged.append(contentsOf: loadedFiles)
                if merged.count > maxSelectionCount {
                    merged = Array(merged.prefix(maxSelectionCount))
                }
                selectedFiles = merged
            }
        }
    }
}
