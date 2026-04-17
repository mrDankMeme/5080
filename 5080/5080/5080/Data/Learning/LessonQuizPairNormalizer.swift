import Foundation

enum LessonQuizPairNormalizer {
    enum Orientation {
        case phraseToTranslation
        case translationToPhrase
    }

    struct MarkdownPair {
        let phrase: String
        let translation: String
    }

    struct PairKey: Hashable {
        let left: String
        let right: String
    }

    static func normalize(
        rawPairs: [LessonQuizPair],
        markdown: String?
    ) -> [LessonQuizPair] {
        let markdownPairs = extractMarkdownPairs(from: markdown)

        guard rawPairs.isEmpty == false else {
            return fallbackPairs(from: markdownPairs, orientation: .translationToPhrase)
        }

        let orientation = inferOrientation(rawPairs: rawPairs, markdownPairs: markdownPairs)
        var result: [LessonQuizPair] = []
        var seen: Set<PairKey> = []

        for pair in rawPairs {
            let normalized = normalizePair(
                pair,
                orientation: orientation,
                markdownPairs: markdownPairs
            )

            guard let normalized else {
                continue
            }

            let key = PairKey(
                left: normalized.question.normalizedQuizToken,
                right: normalized.answer.normalizedQuizToken
            )

            guard seen.contains(key) == false else {
                continue
            }

            seen.insert(key)
            result.append(normalized)
        }

        let desiredCount = min(max(rawPairs.count, 2), max(markdownPairs.count, rawPairs.count))

        if result.count < desiredCount, markdownPairs.isEmpty == false {
            let fallback = fallbackPairs(from: markdownPairs, orientation: orientation)
            for pair in fallback {
                let key = PairKey(
                    left: pair.question.normalizedQuizToken,
                    right: pair.answer.normalizedQuizToken
                )

                if seen.contains(key) {
                    continue
                }

                seen.insert(key)
                result.append(pair)

                if result.count >= desiredCount {
                    break
                }
            }
        }

        return result
    }
}

private extension String {
    var normalizedQuizToken: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
