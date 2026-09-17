import Foundation

enum DictationMode: String, CaseIterable, Identifiable {
    case preview
    case direct
    var id: String { rawValue }
    var label: String { self == .preview ? "Preview" : "Direct (experimental)" }
}

enum PersonalVocabulary {
    static let maximumTerms = 100
    static let maximumTermLength = 80

    static func normalized(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        return terms.compactMap { term in
            let clean = term.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard !clean.isEmpty, clean.count <= maximumTermLength,
                  seen.insert(clean.lowercased()).inserted else { return nil }
            return clean
        }.prefix(maximumTerms).map { $0 }
    }
}
