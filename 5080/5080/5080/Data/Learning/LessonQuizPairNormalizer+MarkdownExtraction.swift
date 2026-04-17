import Foundation

extension LessonQuizPairNormalizer {
    static func extractMarkdownPairs(from markdown: String?) -> [MarkdownPair] {
        guard let markdown else {
            return []
        }

        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var result: [MarkdownPair] = []
        var seen: Set<PairKey> = []

        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if line.hasPrefix("###") {
                let phrase = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                var translation: String?
                var cursor = index + 1

                while cursor < lines.count {
                    let note = lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines)
                    if note.hasPrefix(">") {
                        let raw = String(note.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleaned = cleanInlineMarkdown(raw)
                        if cleaned.isEmpty == false {
                            translation = cleaned
                            break
                        }
                        cursor += 1
                        continue
                    }

                    if note.isEmpty {
                        cursor += 1
                        continue
                    }

                    break
                }

                if let phrase = phrase.trimmedNonEmpty,
                   let translation = translation?.trimmedNonEmpty {
                    let key = PairKey(
                        left: phrase.normalizedQuizToken,
                        right: translation.normalizedQuizToken
                    )
                    if seen.contains(key) == false {
                        seen.insert(key)
                        result.append(MarkdownPair(phrase: phrase, translation: translation))
                    }
                }

                index += 1
                continue
            }

            if line.hasPrefix("- ") {
                let body = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let (left, right) = splitBulletPair(body) {
                    let phrase = cleanInlineMarkdown(left)
                    let translation = cleanInlineMarkdown(right)

                    if let phrase = phrase.trimmedNonEmpty,
                       let translation = translation.trimmedNonEmpty {
                        let key = PairKey(
                            left: phrase.normalizedQuizToken,
                            right: translation.normalizedQuizToken
                        )
                        if seen.contains(key) == false {
                            seen.insert(key)
                            result.append(MarkdownPair(phrase: phrase, translation: translation))
                        }
                    }
                }
            }

            index += 1
        }

        return result
    }

    static func splitBulletPair(_ line: String) -> (String, String)? {
        let separators = [" — ", " – ", " - ", "—", "–"]

        for separator in separators {
            if let range = line.range(of: separator) {
                let left = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let right = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if left.isEmpty == false && right.isEmpty == false {
                    return (left, right)
                }
            }
        }

        return nil
    }

    static func cleanInlineMarkdown(_ value: String) -> String {
        var cleaned = value
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")

        cleaned = cleaned.replacingOccurrences(
            of: #"\[(.*?)\]\((.*?)\)"#,
            with: "$1",
            options: .regularExpression
        )

        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

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
