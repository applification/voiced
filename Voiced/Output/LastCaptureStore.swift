import Foundation
import Observation
import os

@MainActor
@Observable
final class LastCaptureStore {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "last-capture")

    private(set) var last: String? = nil
    private var autoClearTask: Task<Void, Never>? = nil

    func set(_ text: String, autoClearAfter seconds: TimeInterval?) {
        last = text
        Self.logger.info("Stored last transcript; characters=\(text.count, privacy: .public)")
        autoClearTask?.cancel()
        if let s = seconds, s > 0 {
            autoClearTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
                Self.logger.info("Auto-cleared last transcript")
                self?.last = nil
            }
        }
    }

    func clear() {
        autoClearTask?.cancel()
        autoClearTask = nil
        last = nil
        Self.logger.info("Cleared last transcript")
    }
}
