import SwiftUI

struct VocabularySettingsView: View {
    var settings: SettingsStore
    @State private var draft = ""
    @State private var saved = false

    private var lines: [String] { draft.components(separatedBy: .newlines) }
    private var terms: [String] { PersonalVocabulary.normalized(lines) }
    private var validationMessage: String? {
        if lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).count > PersonalVocabulary.maximumTermLength }) {
            return "Keep each word or phrase under 81 characters."
        }
        if Set(lines.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }).count > PersonalVocabulary.maximumTerms {
            return "Keep up to 100 words or phrases."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal vocabulary").font(.headline)
            Text("Add names and specialist words, one per line. Edit a line to change its spelling, or delete it to remove a term.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $draft)
                .font(.body)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1))
                .accessibilityLabel("Vocabulary, one word or phrase per line")
            HStack {
                Text(validationMessage ?? (saved ? "Saved for your next dictation" : "\(terms.count) / 100 terms"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Save vocabulary") {
                    settings.vocabulary = terms
                    draft = terms.joined(separator: "\n")
                    saved = true
                }
                .disabled(validationMessage != nil)
            }
            Text("Used locally by both speech engines. Recognition hints improve the odds of the right spelling; they are not automatic text replacements.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 10)
        .onAppear { draft = settings.vocabulary.joined(separator: "\n") }
        .onChange(of: draft) { saved = false }
    }
}
