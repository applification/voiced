import XCTest
@testable import Voiced

final class CaptureStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoicedTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        fileURL = temporaryDirectory.appendingPathComponent("Captures.json")
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory,
           FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    @MainActor
    func testPersistsAndReloadsCaptures() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let identifier = UUID(uuidString: "E1319284-7E6F-49B2-A144-788762270819")!
        let store = CaptureStore(
            fileURL: fileURL,
            clock: { createdAt },
            idProvider: { identifier }
        )

        let created = store.add(
            text: "  Keep this prompt  ",
            source: .typed,
            sourceApplication: CaptureSourceApplication(
                name: "Example",
                bundleIdentifier: "com.example.app",
                url: URL(string: "https://example.com")
            )
        )

        XCTAssertEqual(created?.text, "Keep this prompt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let relaunchedStore = CaptureStore(fileURL: fileURL)
        XCTAssertEqual(relaunchedStore.items.count, 1)
        XCTAssertEqual(relaunchedStore.items.first?.id, identifier)
        XCTAssertEqual(relaunchedStore.items.first?.source, .typed)
        XCTAssertEqual(relaunchedStore.items.first?.sourceApplication?.bundleIdentifier, "com.example.app")
    }

    @MainActor
    func testStateTransitionsAndEditsPersist() {
        var now = Date(timeIntervalSince1970: 100)
        let store = CaptureStore(fileURL: fileURL, clock: { now })
        let item = store.add(text: "First", source: .voice)!

        now = Date(timeIntervalSince1970: 200)
        store.move(id: item.id, to: .done)
        store.updateText(id: item.id, text: "Revised")

        XCTAssertEqual(store.item(id: item.id)?.status, .done)
        XCTAssertEqual(store.item(id: item.id)?.text, "Revised")
        XCTAssertEqual(store.item(id: item.id)?.updatedAt, now)

        let relaunchedStore = CaptureStore(fileURL: fileURL)
        XCTAssertEqual(relaunchedStore.item(id: item.id)?.status, .done)
        XCTAssertEqual(relaunchedStore.item(id: item.id)?.text, "Revised")
    }

    @MainActor
    func testLegacyNextStatusMigratesToInbox() throws {
        let data = Data("""
        {
          "version": 1,
          "items": [
            {
              "id": "E1319284-7E6F-49B2-A144-788762270819",
              "text": "Legacy queued capture",
              "source": "voice",
              "status": "next",
              "createdAt": "2023-11-14T22:13:20Z",
              "updatedAt": "2023-11-14T22:13:20Z"
            }
          ]
        }
        """.utf8)
        try data.write(to: fileURL)

        let store = CaptureStore(fileURL: fileURL)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.status, .inbox)
    }

    @MainActor
    func testRemovedCaptureCanBeRestored() {
        let store = CaptureStore(fileURL: fileURL)
        let item = store.add(text: "Recover me", source: .typed)!

        let removed = store.remove(id: item.id)
        XCTAssertTrue(store.items.isEmpty)

        store.restore(removed!)

        XCTAssertEqual(store.items, [item])
        let restoredItem = CaptureStore(fileURL: fileURL).items.first
        XCTAssertEqual(restoredItem?.id, item.id)
        XCTAssertEqual(restoredItem?.text, item.text)
        XCTAssertEqual(restoredItem?.status, item.status)
    }

    @MainActor
    func testCorruptFileIsPreservedForRecovery() throws {
        let corruptData = Data("{ definitely not json".utf8)
        try corruptData.write(to: fileURL)

        let store = CaptureStore(
            fileURL: fileURL,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        XCTAssertTrue(store.items.isEmpty)
        guard case .recoveredCorruptFile(let recoveryURL) = store.issue else {
            return XCTFail("Expected a corrupt-file recovery issue")
        }
        XCTAssertEqual(try Data(contentsOf: recoveryURL), corruptData)
        XCTAssertEqual(try Data(contentsOf: fileURL), corruptData)
    }
}
