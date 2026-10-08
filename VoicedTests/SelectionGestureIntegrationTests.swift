import AppKit
import XCTest
@testable import Voiced

final class SelectionGestureIntegrationTests: XCTestCase {
    @MainActor
    func testCapitalLettersDoNotCaptureAndCleanDoubleTapStillSaves() async throws {
        let fixture = try SelectionGestureFixture()
        defer { fixture.cleanUp() }
        fixture.coordinator.start()

        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: .maskShift)
        fixture.hotkeys.send(.keyDown, keyCode: 0, flags: .maskShift)
        fixture.hotkeys.send(.keyUp, keyCode: 0, flags: .maskShift)
        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: [])
        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: .maskShift)
        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: [])
        await Task.yield()
        XCTAssertEqual(fixture.selection.captureCount, 0)
        XCTAssertTrue(fixture.indicator.labels.isEmpty)
        XCTAssertTrue(fixture.captures.items.isEmpty)

        fixture.selection.result = .success(SelectedTextCaptureResult(text: "Keep this selection", sourceApplication: .init(name: "Example")))
        let saved = expectation(description: "Selection saved")
        fixture.indicator.onShow = { saved.fulfill() }
        // The previous clean tap is the first tap of this deliberate gesture.
        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: .maskShift)
        fixture.hotkeys.send(.flagsChanged, keyCode: 56, flags: [])
        await fulfillment(of: [saved], timeout: 1)

        XCTAssertEqual(fixture.captures.items.first?.text, "Keep this selection")
        XCTAssertEqual(fixture.captures.items.first?.source, .selection)
        XCTAssertEqual(fixture.indicator.labels, ["Selection captured"])
    }

    @MainActor
    func testDoubleTapWithoutSelectionDoesNotShowNotchWarning() async throws {
        let fixture = try SelectionGestureFixture()
        defer { fixture.cleanUp() }
        fixture.coordinator.start()
        let attempted = expectation(description: "Selection checked")
        fixture.selection.onCapture = { attempted.fulfill() }
        fixture.doubleTap()
        await fulfillment(of: [attempted], timeout: 1)

        XCTAssertEqual(fixture.selection.captureCount, 1)
        XCTAssertTrue(fixture.indicator.labels.isEmpty)
        XCTAssertTrue(fixture.captures.items.isEmpty)
    }
}

@MainActor
private final class SelectionGestureFixture {
    let hotkeys = SelectionTestHotkeys()
    let selection = SelectionGestureTestCapture()
    let indicator = SelectionTestIndicator()
    let captures: CaptureStore
    let coordinator: AppCoordinator
    private let directory: URL
    private let defaults: UserDefaults
    private let suiteName = "SelectionGestureTests-\(UUID().uuidString)"

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        captures = CaptureStore(fileURL: directory.appendingPathComponent("Captures.json"))
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "didResetForApplicationSupportModelStorage")
        let settings = SettingsStore(userDefaults: defaults)
        settings.hasSeenIntroOnboarding = true
        let tracker = ApplicationContextTracker()
        tracker.remember(.init(processIdentifier: ProcessInfo.processInfo.processIdentifier, name: "Example", bundleIdentifier: nil))
        coordinator = AppCoordinator(
            settings: settings,
            hotkeys: hotkeys,
            transcriber: SelectionTestTranscriber(),
            captures: captures,
            contextTracker: tracker,
            selectedTextCapture: selection,
            indicator: indicator,
            microphonePermissions: SelectionTestMicrophone(),
            soundCues: SelectionTestSounds()
        )
    }

    func doubleTap() {
        for _ in 0..<2 {
            hotkeys.send(.flagsChanged, keyCode: 56, flags: .maskShift)
            hotkeys.send(.flagsChanged, keyCode: 56, flags: [])
        }
    }

    func cleanUp() {
        hotkeys.stopListening()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class SelectionTestHotkeys: HotkeyListening {
    private var handler: KeyHandler?
    func startListening(handler: @escaping KeyHandler) { self.handler = handler }
    func stopListening() { handler = nil }
    func send(_ type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) { handler?(type, keyCode, flags) }
}

@MainActor
private final class SelectionGestureTestCapture: SelectedTextCapturing {
    var result: Result<SelectedTextCaptureResult, SelectedTextCaptureError> = .failure(.noSelection)
    var captureCount = 0
    var onCapture: (() -> Void)?
    func capture(from context: DestinationApplicationContext) async throws -> SelectedTextCaptureResult {
        captureCount += 1
        defer { onCapture?() }
        return try result.get()
    }
}

@MainActor
private final class SelectionTestIndicator: IndicatorPresenting {
    var labels: [String] = []
    var onShow: (() -> Void)?
    func show(state: IndicatorState) { labels.append(state.accessibilityLabel); onShow?() }
    func updateAudioLevel(_ level: Double) {}
    func hide() {}
}

@MainActor
private final class SelectionTestTranscriber: AppTranscribing {
    var isSelectedModelLoaded = false
    var onModelProgress: ((ModelLoadProgress) -> Void)?
    func loadModelIfNeeded() async throws { XCTFail("Selection capture must not load speech models") }
    func transcribeFile(at url: URL) async throws -> String { "" }
    func startLiveTranscription(onUpdate: @escaping @MainActor (LiveTranscriptState) -> Void,
                               onAudioLevel: @escaping @MainActor (Double) -> Void) async throws {}
    func stopLiveTranscription() async throws -> String { "" }
}

@MainActor
private final class SelectionTestMicrophone: MicrophonePermissionManaging {
    var micAuthorized = false
    func refreshStatuses() {}
    func requestMicrophone(completion: @Sendable @escaping (Bool) -> Void) {}
}

@MainActor
private final class SelectionTestSounds: SoundCuePlaying {
    func playActivation() { XCTFail("Selection capture must not play dictation sounds") }
    func playDeactivation() { XCTFail("Selection capture must not play dictation sounds") }
}
