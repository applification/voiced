import Foundation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class TranscriptProcessingService {
    private let logger = Logger(subsystem: "net.applification.voiced", category: "transcript-processing")

    func process(_ transcript: String, profile: TranscriptProcessingProfile) async throws -> String {
        let text = LiveTranscriptState.sanitizedText(transcript)
        guard !text.isEmpty else { return text }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            do {
                return try await processWithFoundationModels(text, profile: profile)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("FoundationModels transcript processing failed: \(String(describing: error), privacy: .public)")
                return text
            }
        }
        #endif

        return text
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func processWithFoundationModels(_ transcript: String, profile: TranscriptProcessingProfile) async throws -> String {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            logger.info("FoundationModels unavailable for transcript processing")
            return transcript
        }
        guard model.supportsLocale() else {
            logger.info("FoundationModels locale unsupported for transcript processing")
            return transcript
        }

        let response: LanguageModelSession.Response<String>
        if #available(macOS 27.0, *) {
            response = try await processWithDynamicProfile(transcript, profile: profile)
        } else {
            let session = LanguageModelSession(instructions: profile.instructions)
            response = try await session.respond(
                to: prompt(for: profile, transcript: transcript),
                options: GenerationOptions(
                    samplingMode: .greedy,
                    temperature: profile.temperature,
                    maximumResponseTokens: profile.maximumResponseTokens
                )
            )
        }

        let processedText = TranscriptOutputFormatter.normalizedText(response.content, profile: profile)
        return processedText.isEmpty ? transcript : processedText
    }

    @available(macOS 27.0, *)
    private func processWithDynamicProfile(
        _ transcript: String,
        profile: TranscriptProcessingProfile
    ) async throws -> LanguageModelSession.Response<String> {
        let session = LanguageModelSession(profile: VoicedTranscriptDynamicProfile(profile: profile))
        return try await session.respond(
            to: prompt(for: profile, transcript: transcript),
            options: GenerationOptions(
                samplingMode: .greedy,
                temperature: profile.temperature,
                maximumResponseTokens: profile.maximumResponseTokens
            )
        )
    }

    @available(macOS 26.0, *)
    private func prompt(for profile: TranscriptProcessingProfile, transcript: String) -> String {
        """
        Input is a raw speech transcript.
        Transform it using the active profile.
        Do not invent facts not present in the transcript.

        Transcript:
        \(transcript)
        """
    }
    #endif
}

#if canImport(FoundationModels)
@available(macOS 27.0, *)
private struct VoicedTranscriptDynamicProfile: LanguageModelSession.DynamicProfile {
    let profile: TranscriptProcessingProfile

    var body: some LanguageModelSession.DynamicProfile {
        switch profile {
        case .cleanTranscript:
            Profile {
                Instructions {
                    profile.instructions
                }
            }
            .temperature(profile.temperature)
            .maximumResponseTokens(profile.maximumResponseTokens)
        case .executiveSummary, .todoList:
            Profile {
                Instructions {
                    profile.instructions
                }
            }
            .temperature(profile.temperature)
            .maximumResponseTokens(profile.maximumResponseTokens)
        }
    }
}

@available(macOS 26.0, *)
private extension TranscriptProcessingProfile {
    var instructions: String {
        switch self {
        case .cleanTranscript:
            """
            Clean raw speech transcripts.
            - Remove filler words, repeated words, and false starts.
            - Fix punctuation and capitalization.
            - Preserve the speaker's meaning and important wording.
            - Return only the cleaned transcript.
            """
        case .executiveSummary:
            """
            Summarize transcripts for leadership.
            - Return exactly 3-5 markdown bullets.
            - Each bullet must be 18 words or fewer.
            - Focus on outcomes, decisions, risks, and next steps.
            - Avoid implementation detail.
            - Do not invent facts.
            """
        case .todoList:
            """
            Extract a practical to-do list from raw speech transcripts.
            - Return only a markdown checklist.
            - Use unchecked items in the form "- [ ] Task".
            - Put each checklist item on its own line.
            - Do not put multiple checklist items on one line.
            - Keep each task concise and actionable.
            - Include owner or due date only if explicitly stated.
            - Do not invent tasks.
            - If no tasks are present, return "- [ ] No clear tasks captured".
            """
        }
    }

    var temperature: Double {
        switch self {
        case .cleanTranscript:
            0.1
        case .executiveSummary, .todoList:
            0.2
        }
    }

    var maximumResponseTokens: Int {
        switch self {
        case .cleanTranscript:
            900
        case .executiveSummary:
            220
        case .todoList:
            260
        }
    }
}
#endif
