import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let cleaned = trimmed
        return cleaned.isEmpty ? nil : cleaned
    }
}
