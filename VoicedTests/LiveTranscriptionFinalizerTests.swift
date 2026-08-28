import XCTest
@testable import Voiced
import WhisperKit

final class LiveTranscriptionFinalizerTests: XCTestCase {
    func testFinalDecodeStartsAtConfirmedBoundaryAndIncludesAudioEnding() {
        let options = LiveTranscriptionFinalizer.decodingOptions(
            tokenizer: FinalizerStubWhisperTokenizer(),
            confirmedThroughSeconds: 1.25,
            audioSampleCount: WhisperKit.sampleRate * 2
        )

        XCTAssertEqual(options.clipTimestamps, [1.25])
        XCTAssertEqual(options.windowClipTime, 0)
        XCTAssertFalse(options.wordTimestamps)
    }

    func testFinalDecodeStartsAtBeginningForShortUnconfirmedRecording() {
        let options = LiveTranscriptionFinalizer.decodingOptions(
            tokenizer: FinalizerStubWhisperTokenizer(),
            confirmedThroughSeconds: 0,
            audioSampleCount: WhisperKit.sampleRate / 2
        )

        XCTAssertTrue(options.clipTimestamps.isEmpty)
        XCTAssertEqual(options.windowClipTime, 0)
        XCTAssertTrue(
            LiveTranscriptionFinalizer.hasAudioToDecode(
                audioSampleCount: WhisperKit.sampleRate / 2,
                confirmedThroughSeconds: 0
            )
        )
    }

    func testFinalDecodeClampsConfirmedBoundaryToAudioDuration() {
        let options = LiveTranscriptionFinalizer.decodingOptions(
            tokenizer: FinalizerStubWhisperTokenizer(),
            confirmedThroughSeconds: 2,
            audioSampleCount: WhisperKit.sampleRate
        )

        XCTAssertEqual(options.clipTimestamps, [1])
        XCTAssertFalse(
            LiveTranscriptionFinalizer.hasAudioToDecode(
                audioSampleCount: WhisperKit.sampleRate,
                confirmedThroughSeconds: 2
            )
        )
    }

    func testFinalTailReplacesProvisionalTailAfterConfirmedText() {
        XCTAssertEqual(
            LiveTranscriptionFinalizer.mergedText(
                confirmedText: "This part is confirmed.",
                finalTailText: "The final word is preserved.",
                fallbackText: "This part is confirmed. The final"
            ),
            "This part is confirmed. The final word is preserved."
        )
    }

    func testEmptyFinalDecodeKeepsLiveFallback() {
        XCTAssertEqual(
            LiveTranscriptionFinalizer.mergedText(
                confirmedText: "This part is confirmed.",
                finalTailText: "[silence]",
                fallbackText: "This part is confirmed. Keep this provisional ending."
            ),
            "This part is confirmed. Keep this provisional ending."
        )
    }
}

private struct FinalizerStubWhisperTokenizer: WhisperTokenizer {
    let specialTokens = SpecialTokens(
        endToken: 50_257,
        englishToken: 50_259,
        noSpeechToken: 50_362,
        noTimestampsToken: 50_363,
        specialTokenBegin: 50_257,
        startOfPreviousToken: 50_361,
        startOfTranscriptToken: 50_258,
        timeTokenBegin: 50_364,
        transcribeToken: 50_358,
        translateToken: 50_357,
        whitespaceToken: 220
    )

    let allLanguageTokens: Set<Int> = []

    func encode(text: String) -> [Int] {
        [101, 202]
    }

    func decode(tokens: [Int]) -> String {
        ""
    }

    func convertTokenToId(_ token: String) -> Int? {
        nil
    }

    func convertIdToToken(_ id: Int) -> String? {
        nil
    }

    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        ([], [])
    }
}
