import Foundation
import os

enum Log {
    static let app = Logger(subsystem: "com.voiced.app", category: "app")
    static let audio = Logger(subsystem: "com.voiced.app", category: "audio")
    static let ml = Logger(subsystem: "com.voiced.app", category: "ml")
}

@inline(__always)
func logTranscriptRedacted(_ text: String) {
    Log.ml.info("Transcript length: \(text.count, privacy: .public). Content: <redacted>")
}
