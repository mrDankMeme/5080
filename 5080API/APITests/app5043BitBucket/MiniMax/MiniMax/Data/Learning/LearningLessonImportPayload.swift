import Foundation

struct LearningLessonImportPayload: Codable {
    let languageCode: String
    let level: String
    let lessonNumber: Int
    let audioBasename: String?
    let markdown: String?
    let quizPairs: [LessonQuizPair]
    let sourceSpreadsheet: String?
    let title: String?
    let subtitle: String?

    func toManifest() -> LessonContentManifest {
        let normalizedQuizPairs = LessonQuizPairNormalizer.normalize(
            rawPairs: quizPairs,
            markdown: markdown
        )

        return LessonContentManifest(
            sourceSpreadsheet: sourceSpreadsheet,
            sourceLanguageCode: languageCode,
            sourceLevel: level,
            sourceLessonNumber: lessonNumber,
            audioBasename: audioBasename,
            markdown: markdown,
            quizPairs: normalizedQuizPairs
        )
    }

    func withSourceSpreadsheetFallback(_ fallback: String) -> LearningLessonImportPayload {
        LearningLessonImportPayload(
            languageCode: languageCode,
            level: level,
            lessonNumber: lessonNumber,
            audioBasename: audioBasename,
            markdown: markdown,
            quizPairs: quizPairs,
            sourceSpreadsheet: sourceSpreadsheet ?? fallback,
            title: title,
            subtitle: subtitle
        )
    }
}
