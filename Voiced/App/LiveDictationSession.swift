import Foundation

@MainActor
final class LiveDictationSession {
    private(set) var isPushToTalkDown = false
    private(set) var shouldCancel = false
    private var recordingStartedAt: Date?

    func pressPushToTalk() {
        isPushToTalkDown = true
    }

    func releasePushToTalk() -> String {
        isPushToTalkDown = false
        return finishRecordingDurationBucket()
    }

    func beginRecording() {
        shouldCancel = false
        recordingStartedAt = Date()
    }

    func cancelRecording() -> String {
        shouldCancel = true
        isPushToTalkDown = false
        return finishRecordingDurationBucket()
    }

    func resetCancellation() {
        shouldCancel = false
    }

    func reset() {
        isPushToTalkDown = false
        shouldCancel = false
        recordingStartedAt = nil
    }

    private func finishRecordingDurationBucket() -> String {
        defer { recordingStartedAt = nil }
        guard let recordingStartedAt else { return "unknown" }
        let duration = Date().timeIntervalSince(recordingStartedAt)
        switch duration {
        case ..<1:
            return "<1s"
        case ..<3:
            return "1-3s"
        case ..<10:
            return "3-10s"
        case ..<30:
            return "10-30s"
        default:
            return "30s+"
        }
    }
}
