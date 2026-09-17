import XCTest
@testable import Voiced

final class PersonalVocabularyTests: XCTestCase {
    func testNormalizationKeepsPreferredSpellingAndPhraseBoundaries() {
        XCTAssertEqual(PersonalVocabulary.normalized(["  NVIDIA  ", "nvidia", "", "  M1   Pro\n", "Applification"]),
                       ["NVIDIA", "M1 Pro", "Applification"])
    }

    func testVocabularyBoundsAndClearing() {
        XCTAssertEqual(PersonalVocabulary.normalized((0..<150).map { "Term \($0)" }).count, 100)
        XCTAssertEqual(PersonalVocabulary.normalized([String(repeating: "x", count: 81)]), [])
        XCTAssertEqual(PersonalVocabulary.normalized([]), [])
    }

    func testUserVocabularyAndModesPersistIncludingEmptyVocabulary() throws {
        let name = "VoicedVocabularyTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = SettingsStore(userDefaults: defaults)
        first.vocabulary = ["Rufus", "Parakeet"]
        first.dictationMode = .direct
        first.cleanUpAfterDictation = true
        let restored = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(restored.vocabulary, ["Rufus", "Parakeet"])
        XCTAssertEqual(restored.dictationMode, .direct)
        XCTAssertTrue(restored.cleanUpAfterDictation)
        restored.vocabulary = []
        XCTAssertEqual(SettingsStore(userDefaults: defaults).vocabulary, [])
    }
}
