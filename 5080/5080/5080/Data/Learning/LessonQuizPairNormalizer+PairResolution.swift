import Foundation

extension LessonQuizPairNormalizer {
    static func normalizePair(
        _ pair: LessonQuizPair,
        orientation: Orientation,
        markdownPairs: [MarkdownPair]
    ) -> LessonQuizPair? {
        var question = pair.question.trimmedNonEmpty
        var answer = pair.answer.trimmedNonEmpty

        if question == nil && answer == nil {
            return nil
        }

        if let existingQuestion = question, let existingAnswer = answer {
            return LessonQuizPair(question: existingQuestion, answer: existingAnswer)
        }

        if markdownPairs.isEmpty == false {
            if let existingQuestion = question, answer == nil {
                if let sourcePair = findMatchingPair(for: existingQuestion, in: markdownPairs) {
                    let resolved = resolvedPair(
                        sourcePair: sourcePair,
                        knownValue: existingQuestion,
                        knownIsQuestion: true,
                        orientation: orientation
                    )
                    question = resolved.question
                    answer = resolved.answer
                }
            } else if question == nil, let existingAnswer = answer {
                if let sourcePair = findMatchingPair(for: existingAnswer, in: markdownPairs) {
                    let resolved = resolvedPair(
                        sourcePair: sourcePair,
                        knownValue: existingAnswer,
                        knownIsQuestion: false,
                        orientation: orientation
                    )
                    question = resolved.question
                    answer = resolved.answer
                }
            }
        }

        guard let question, let answer else {
            return nil
        }

        return LessonQuizPair(question: question, answer: answer)
    }

    static func fallbackPairs(
        from markdownPairs: [MarkdownPair],
        orientation: Orientation
    ) -> [LessonQuizPair] {
        markdownPairs.map { pair in
            switch orientation {
            case .phraseToTranslation:
                return LessonQuizPair(question: pair.phrase, answer: pair.translation)
            case .translationToPhrase:
                return LessonQuizPair(question: pair.translation, answer: pair.phrase)
            }
        }
    }

    static func inferOrientation(
        rawPairs: [LessonQuizPair],
        markdownPairs: [MarkdownPair]
    ) -> Orientation {
        guard markdownPairs.isEmpty == false else {
            return .translationToPhrase
        }

        var phraseToTranslation = 0
        var translationToPhrase = 0

        for pair in rawPairs {
            guard let question = pair.question.trimmedNonEmpty,
                  let answer = pair.answer.trimmedNonEmpty else {
                continue
            }

            let questionToken = question.normalizedQuizToken
            let answerToken = answer.normalizedQuizToken

            for sourcePair in markdownPairs {
                if questionToken == sourcePair.phrase.normalizedQuizToken &&
                    answerToken == sourcePair.translation.normalizedQuizToken {
                    phraseToTranslation += 1
                    break
                }

                if questionToken == sourcePair.translation.normalizedQuizToken &&
                    answerToken == sourcePair.phrase.normalizedQuizToken {
                    translationToPhrase += 1
                    break
                }
            }
        }

        if translationToPhrase >= phraseToTranslation {
            return .translationToPhrase
        }

        return .phraseToTranslation
    }

    static func resolvedPair(
        sourcePair: MarkdownPair,
        knownValue: String,
        knownIsQuestion: Bool,
        orientation: Orientation
    ) -> (question: String, answer: String) {
        let knownToken = knownValue.normalizedQuizToken
        let phraseToken = sourcePair.phrase.normalizedQuizToken
        let translationToken = sourcePair.translation.normalizedQuizToken

        switch orientation {
        case .phraseToTranslation:
            if knownIsQuestion {
                if knownToken == phraseToken {
                    return (question: sourcePair.phrase, answer: sourcePair.translation)
                }
                if knownToken == translationToken {
                    return (question: sourcePair.translation, answer: sourcePair.phrase)
                }
                return (question: knownValue, answer: sourcePair.translation)
            }

            if knownToken == translationToken {
                return (question: sourcePair.phrase, answer: sourcePair.translation)
            }
            if knownToken == phraseToken {
                return (question: sourcePair.translation, answer: sourcePair.phrase)
            }
            return (question: sourcePair.phrase, answer: knownValue)
        case .translationToPhrase:
            if knownIsQuestion {
                if knownToken == translationToken {
                    return (question: sourcePair.translation, answer: sourcePair.phrase)
                }
                if knownToken == phraseToken {
                    return (question: sourcePair.translation, answer: sourcePair.phrase)
                }
                return (question: knownValue, answer: sourcePair.phrase)
            }

            if knownToken == phraseToken {
                return (question: sourcePair.translation, answer: sourcePair.phrase)
            }
            if knownToken == translationToken {
                return (question: sourcePair.phrase, answer: sourcePair.translation)
            }
            return (question: sourcePair.translation, answer: knownValue)
        }
    }

    static func findMatchingPair(
        for value: String,
        in pairs: [MarkdownPair]
    ) -> MarkdownPair? {
        let token = value.normalizedQuizToken
        guard token.isEmpty == false else { return nil }

        if let exact = pairs.first(where: {
            $0.phrase.normalizedQuizToken == token || $0.translation.normalizedQuizToken == token
        }) {
            return exact
        }

        return pairs.first(where: {
            let phrase = $0.phrase.normalizedQuizToken
            let translation = $0.translation.normalizedQuizToken
            return phrase.contains(token) || token.contains(phrase)
                || translation.contains(token) || token.contains(translation)
        })
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
