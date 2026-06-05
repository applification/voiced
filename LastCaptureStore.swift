import Foundation
import Observation

@MainActor
@Observable
final class LastCaptureStore {
    private(set) var last: String? = nil
    private var autoClearTask: Task<Void, Never>? = nil

    func set(_ text: String, autoClearAfter seconds: TimeInterval?) {
        last = text
        autoClearTask?.cancel()
        if let s = seconds, s > 0 {
            autoClearTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
                self?.last = nil
            }
        }
    }

    func clear() {
        autoClearTask?.cancel()
        autoClearTask = nil
        last = nil
    }
}
