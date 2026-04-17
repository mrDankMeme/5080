import Foundation

protocol LearningLessonImportsLoading {
    func loadLessonImports() -> [LearningLessonImportPayload]
}

final class BundleLearningLessonImportsLoader: LearningLessonImportsLoading {

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadLessonImports() -> [LearningLessonImportPayload] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) ?? []

        guard urls.isEmpty == false else {
            return []
        }

        let decoder = JSONDecoder()
        var imports: [LearningLessonImportPayload] = []

        for url in urls {
            guard let data = try? Data(contentsOf: url) else {
                continue
            }

            if let document = try? decoder.decode(LearningLessonImportsDocument.self, from: data),
               document.lessons.isEmpty == false {
                imports.append(contentsOf: document.lessons.map { payload in
                    payload.withSourceSpreadsheetFallback(url.lastPathComponent)
                })
                continue
            }

            if let lessons = try? decoder.decode([LearningLessonImportPayload].self, from: data),
               lessons.isEmpty == false {
                imports.append(contentsOf: lessons.map { payload in
                    payload.withSourceSpreadsheetFallback(url.lastPathComponent)
                })
            }
        }

        return imports.sorted { lhs, rhs in
            if lhs.languageCode != rhs.languageCode {
                return lhs.languageCode < rhs.languageCode
            }

            if lhs.level != rhs.level {
                return lhs.level < rhs.level
            }

            return lhs.lessonNumber < rhs.lessonNumber
        }
    }
}

private struct LearningLessonImportsDocument: Decodable {
    let lessons: [LearningLessonImportPayload]
}
