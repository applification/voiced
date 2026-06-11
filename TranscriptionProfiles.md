import Foundation
import SwiftUI

// MARK: - OnDeviceLLMProvider Protocol and Types

protocol OnDeviceLLMProvider {
    var name: String { get }
    var modelIdentifier: String { get }

    func complete(
        prompt: String,
        parameters: GenerationParameters
    ) async throws -> String

    func completeJSON<T: Decodable>(
        prompt: String,
        parameters: GenerationParameters,
        as type: T.Type
    ) async throws -> T
}

struct GenerationParameters {
    var maxTokens: Int
    var temperature: Double
    var topP: Double?
    var stop: [String] = []
    var systemInstruction: String? = nil
}

struct TranscriptionProfile {
    let id: String
    let displayName: String
    let provider: OnDeviceLLMProvider
    let tasks: [TranscriptionTaskTemplate]
}

enum OutputFormat {
    case markdown
    case jsonSchema(String) // name/description of schema
    case plain
}

struct TranscriptionTaskTemplate {
    let kind: TaskKind
    let promptTemplate: (String) -> String
    let outputFormat: OutputFormat
    let parameters: GenerationParameters
}

enum TaskKind: String {
    case cleanup
    case structure
    case summarize
    case rewriteAngle
}

// MARK: - Task Templates

let cleanupTask = TranscriptionTaskTemplate(
    kind: .cleanup,
    promptTemplate: { text in
        """
        You are a transcript cleaner. Fix casing and punctuation. Remove filler words like "um" and "uh".
        Do not add information not present in the text. Preserve speaker names if present.

        Text:
        \(text)
        """
    },
    outputFormat: .plain,
    parameters: GenerationParameters(maxTokens: 800, temperature: 0.2, topP: 0.9, stop: [], systemInstruction: "Be concise and faithful.")
)

let structureMarkdownTask = TranscriptionTaskTemplate(
    kind: .structure,
    promptTemplate: { text in
        """
        Reflow the following transcript into clear paragraphs and lists using Markdown.
        - Use headings where appropriate.
        - Convert enumerations into bullet lists.
        - Detect code-like content and render in fenced code blocks with a language tag if guessable.
        - Do not invent facts.

        Transcript:
        \(text)
        """
    },
    outputFormat: .markdown,
    parameters: GenerationParameters(maxTokens: 1200, temperature: 0.3, topP: 0.9)
)

let jsonSemanticTask = TranscriptionTaskTemplate(
    kind: .structure,
    promptTemplate: { text in
        """
        Return JSON only. Schema:
        {
          "summary": "string",
          "sections": [ { "title": "string", "paragraphs": ["string"] } ],
          "actionItems": [ { "text": "string", "owner": "string|null", "dueDate": "string|null" } ],
          "codeBlocks": [ { "language": "string|null", "code": "string" } ]
        }
        Only extract from the transcript. Do not add information.

        Transcript:
        \(text)
        """
    },
    outputFormat: .jsonSchema("SemanticStructure"),
    parameters: GenerationParameters(maxTokens: 1200, temperature: 0.2, topP: 0.95)
)

// MARK: - Example Provider Implementation Placeholder

/// Example placeholder provider for Apple Foundation Models
struct AppleFoundationModelProvider: OnDeviceLLMProvider {
    let modelIdentifier: String
    var name: String { "AppleFoundationModelProvider" }

    func complete(
        prompt: String,
        parameters: GenerationParameters
    ) async throws -> String {
        // Placeholder implementation
        return "Simulated response for prompt."
    }

    func completeJSON<T>(
        prompt: String,
        parameters: GenerationParameters,
        as type: T.Type
    ) async throws -> T where T : Decodable {
        // Placeholder implementation: simulate JSON decoding failure or success
        fatalError("completeJSON is not implemented in the placeholder provider")
    }
}

// MARK: - Example Profiles

let appleFoundationProvider = AppleFoundationModelProvider(modelIdentifier: "foundation-small")

let editCleanStructureMD = TranscriptionProfile(
    id: "edit-clean-structure-md",
    displayName: "Edit: Clean + Structure (Markdown)",
    provider: appleFoundationProvider,
    tasks: [cleanupTask, structureMarkdownTask]
)

let notesJSONSummary = TranscriptionProfile(
    id: "notes-json-summary",
    displayName: "Notes: JSON + Summary",
    provider: appleFoundationProvider,
    tasks: [jsonSemanticTask]
)

// MARK: - Segment and RenderableOutput Placeholder Types

struct Segment {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

// Example RenderableOutput could be markdown string, JSON structure, or plain text
enum RenderableOutput {
    case markdown(String)
    case json(Data)
    case plain(String)
}

// MARK: - PostProcessor Actor

actor PostProcessor {
    let profile: TranscriptionProfile

    init(profile: TranscriptionProfile) {
        self.profile = profile
    }

    func stitch(_ segments: [Segment]) -> String {
        segments.map { $0.text }.joined(separator: "\n")
    }

    func render(_ text: String) -> RenderableOutput {
        // Based on last task's output format, choose rendering
        guard let lastTask = profile.tasks.last else {
            return .plain(text)
        }
        switch lastTask.outputFormat {
        case .markdown:
            return .markdown(text)
        case .jsonSchema:
            return .plain(text)
        case .plain:
            return .plain(text)
        }
    }

    func process(finalizedSegments: [Segment]) async throws -> RenderableOutput {
        var current = stitch(finalizedSegments)

        for task in profile.tasks {
            let prompt = task.promptTemplate(current)
            switch task.outputFormat {
            case .plain, .markdown:
                current = try await profile.provider.complete(prompt: prompt, parameters: task.parameters)
            case .jsonSchema:
                // Try decoding JSON, fallback to raw string if needed
                do {
                    let decoded = try await profile.provider.completeJSON(prompt: prompt, parameters: task.parameters, as: Data.self)
                    // For demonstration, convert Data to JSON string
                    if let jsonString = String(data: decoded, encoding: .utf8) {
                        current = jsonString
                    } else {
                        current = String(data: decoded, encoding: .utf8) ?? ""
                    }
                } catch {
                    // Fallback to raw string if JSON decode fails
                    current = try await profile.provider.complete(prompt: prompt, parameters: task.parameters)
                }
            }
        }
        return render(current)
    }
}

// MARK: - RichTextView: Markdown Renderer

struct RichTextView: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
                .textSelection(.enabled)
                .padding()
        } else {
            Text(markdown)
                .monospaced()
                .padding()
        }
    }
}
