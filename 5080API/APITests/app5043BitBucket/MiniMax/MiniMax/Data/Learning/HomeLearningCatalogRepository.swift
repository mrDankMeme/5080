import Foundation

final class LocalLearningCatalogRepository: LearningCatalogRepository {

    private let importsLoader: LearningLessonImportsLoading

    init(importsLoader: LearningLessonImportsLoading = BundleLearningLessonImportsLoader()) {
        self.importsLoader = importsLoader
    }

    func fetchLanguages() -> [LearningLanguage] {
        var languages = languageSeeds.map(makeLanguage)
        applyLessonImports(importsLoader.loadLessonImports(), to: &languages)
        return languages
    }

    private func makeLanguage(from seed: LanguageSeed) -> LearningLanguage {
        let levels = CEFRLevel.allCases.map { level in
            return LearningLevel(
                id: "\(seed.code)-\(level.rawValue.lowercased())",
                level: level,
                title: level.title,
                description: level.description,
                lessonCount: 0,
                lessons: []
            )
        }

        return LearningLanguage(
            id: seed.code,
            code: seed.code,
            title: seed.title,
            badgeText: seed.badgeText,
            tintHex: seed.tintHex,
            levels: levels
        )
    }

    private func applyLessonImports(
        _ imports: [LearningLessonImportPayload],
        to languages: inout [LearningLanguage]
    ) {
        for payload in imports {
            let languageCode = payload.languageCode.lowercased()
            guard let level = CEFRLevel(rawValue: payload.level.uppercased()) else {
                continue
            }

            guard let languageIndex = languages.firstIndex(where: { $0.code == languageCode || $0.id == languageCode }) else {
                continue
            }

            guard let levelIndex = languages[languageIndex].levels.firstIndex(where: { $0.level == level }) else {
                continue
            }

            let lessonOrder = max(1, payload.lessonNumber)
            let levelModel = languages[languageIndex].levels[levelIndex]

            if let existingIndex = levelModel.lessons.firstIndex(where: { $0.order == lessonOrder }) {
                languages[languageIndex].levels[levelIndex].lessons[existingIndex].contentManifest = payload.toManifest()

                let fallbackTitle = payload.title?.trimmedNonEmpty
                    ?? extractTitleFromMarkdown(payload.markdown)
                    ?? "Lesson \(lessonOrder)"
                languages[languageIndex].levels[levelIndex].lessons[existingIndex].title = fallbackTitle

                let fallbackSubtitle = payload.subtitle?.trimmedNonEmpty
                    ?? extractSubtitleFromMarkdown(payload.markdown)
                    ?? "Lesson \(lessonOrder)"
                languages[languageIndex].levels[levelIndex].lessons[existingIndex].subtitle = fallbackSubtitle
            } else {
                let lessonID = "\(languageCode)-\(level.rawValue.lowercased())-\(lessonOrder)"
                let fallbackTitle = payload.title?.trimmedNonEmpty
                    ?? extractTitleFromMarkdown(payload.markdown)
                    ?? "Lesson \(lessonOrder)"
                let fallbackSubtitle = payload.subtitle?.trimmedNonEmpty
                    ?? extractSubtitleFromMarkdown(payload.markdown)
                    ?? "Lesson \(lessonOrder)"

                let importedLesson = LearningLesson(
                    id: lessonID,
                    order: lessonOrder,
                    title: fallbackTitle,
                    subtitle: fallbackSubtitle,
                    contentManifest: payload.toManifest()
                )

                languages[languageIndex].levels[levelIndex].lessons.append(importedLesson)
                languages[languageIndex].levels[levelIndex].lessons.sort { $0.order < $1.order }
            }
        }

        for languageIndex in languages.indices {
            for levelIndex in languages[languageIndex].levels.indices {
                languages[languageIndex].levels[levelIndex].lessons.sort { $0.order < $1.order }
                languages[languageIndex].levels[levelIndex].lessonCount = languages[languageIndex].levels[levelIndex].lessons.count
            }
        }
    }

    private func extractTitleFromMarkdown(_ markdown: String?) -> String? {
        guard let markdown else {
            return nil
        }

        let heading = markdown
            .split(separator: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("##") })

        return heading?
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(
                of: #"^\s*Lesson\s+\d+\s*:\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmedNonEmpty
    }

    private func extractSubtitleFromMarkdown(_ markdown: String?) -> String? {
        guard let markdown else {
            return nil
        }

        for line in markdown.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmed.isEmpty == false else {
                continue
            }

            if trimmed.hasPrefix("#")
                || trimmed.hasPrefix(">")
                || trimmed.hasPrefix("|")
                || trimmed.hasPrefix("- ")
                || trimmed.hasPrefix("* ")
                || trimmed == "---" {
                continue
            }

            let normalized = cleanMarkdownForSubtitle(trimmed).trimmedNonEmpty
            guard let normalized else {
                continue
            }

            if normalized.count <= 88 {
                return normalized
            }

            let shortened = String(normalized.prefix(85)).trimmingCharacters(in: .whitespacesAndNewlines)
            return shortened + "..."
        }

        return nil
    }

    private func cleanMarkdownForSubtitle(_ value: String) -> String {
        var cleaned = value

        cleaned = cleaned.replacingOccurrences(
            of: #"\[(.*?)\]\((.*?)\)"#,
            with: "$1",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: #"[*_`]"#, with: "", options: .regularExpression)

        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let languageSeeds: [LanguageSeed] = [
        LanguageSeed(code: "fr", title: "French", badgeText: "FR", tintHex: "EA5A4D"),
        LanguageSeed(code: "de", title: "German", badgeText: "DE", tintHex: "313131"),
        LanguageSeed(code: "it", title: "Italian", badgeText: "IT", tintHex: "4FAF75"),
        LanguageSeed(code: "es", title: "Spanish", badgeText: "ES", tintHex: "D88B16"),
        LanguageSeed(code: "pt", title: "Portuguese", badgeText: "PT", tintHex: "1F8A5C"),
        LanguageSeed(code: "zh", title: "Chinese", badgeText: "ZH", tintHex: "E35A3D")
    ]

    private struct LanguageSeed {
        let code: String
        let title: String
        let badgeText: String
        let tintHex: String
    }

}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
