import Foundation
import os

enum Log {
    static let app = Logger(subsystem: "net.applification.voiced", category: "app")
    static let audio = Logger(subsystem: "net.applification.voiced", category: "audio")
    static let ml = Logger(subsystem: "net.applification.voiced", category: "ml")
}

@inline(__always)
func logTranscriptRedacted(_ text: String) {
    Log.ml.info("Transcript length: \(text.count, privacy: .public). Content: <redacted>")
}
