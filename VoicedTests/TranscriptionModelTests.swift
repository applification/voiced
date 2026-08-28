import XCTest
@testable import Voiced
import WhisperKit

final class TranscriptionModelTests: XCTestCase {
    func testStableSettingsIdentifiersUseEnglishWhisperKitVariants() {
        XCTAssertEqual(TranscriptionModel.tiny.rawValue, "tiny")
        XCTAssertEqual(TranscriptionModel.base.rawValue, "base")
        XCTAssertEqual(TranscriptionModel.small.rawValue, "small")

        XCTAssertEqual(TranscriptionModel.tiny.whisperKitVariant, "tiny.en")
        XCTAssertEqual(TranscriptionModel.base.whisperKitVariant, "base.en")
        XCTAssertEqual(TranscriptionModel.small.whisperKitVariant, "small.en")
        XCTAssertEqual(
            TranscriptionModel.largeAccuracy.whisperKitVariant,
            "large-v3-v20240930_626MB"
        )
    }

    func testEnglishVariantsResolveToTheirExpectedCacheFolders() {
        XCTAssertEqual(TranscriptionModel.tiny.cacheFolderName, "openai_whisper-tiny.en")
        XCTAssertEqual(TranscriptionModel.base.cacheFolderName, "openai_whisper-base.en")
        XCTAssertEqual(TranscriptionModel.small.cacheFolderName, "openai_whisper-small.en")
    }

    func testVocabularyOptionsForceEnglishAndFilterSpecialTokens() {
        let options = TranscriptionVocabulary.decodingOptions(
            tokenizer: StubWhisperTokenizer(),
            wordTimestamps: true
        )

        XCTAssertEqual(options.language, "en")
        XCTAssertTrue(options.usePrefillPrompt)
        XCTAssertTrue(options.skipSpecialTokens)
        XCTAssertTrue(options.wordTimestamps)
        XCTAssertEqual(options.promptTokens, [101, 202])
    }

    func testVocabularyContainsValidatedProductNames() {
        XCTAssertEqual(
            TranscriptionVocabulary.promptText,
            "Voiced, WhisperKit, SwiftUI, Xcode, Contexture, Applification"
        )
    }
}

private struct StubWhisperTokenizer: WhisperTokenizer {
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
        [101, specialTokens.specialTokenBegin, 202]
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
