import Darwin
import Foundation

enum SpeechRuntimePrivacy {
    /// FluidAudio 0.15.7 has no logger-disable API and prints decoded words to stderr
    /// in Debug builds. Silence the process console before loading it. Voiced's own
    /// content-free OSLog diagnostics still work; never restore stderr mid-session,
    /// because the dependency emits some messages from detached tasks.
    static func silenceDependencyConsole() throws {
        let sink = open("/dev/null", O_WRONLY)
        guard sink >= 0 else { throw POSIXError(.EIO) }
        defer { close(sink) }
        guard dup2(sink, STDERR_FILENO) >= 0 else { throw POSIXError(.EIO) }
    }
}
