import Foundation

enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case voice
    case selection
    case typed

    var label: String {
        switch self {
        case .voice: "Voice"
        case .selection: "Selection"
        case .typed: "Typed"
        }
    }

    var symbolName: String {
        switch self {
        case .voice: "waveform"
        case .selection: "selection.pin.in.out"
        case .typed: "keyboard"
        }
    }
}

enum CaptureStatus: String, CaseIterable, Identifiable, Sendable {
    case inbox
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inbox: "Inbox"
        case .done: "Done"
        }
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .done: "checkmark.circle"
        }
    }
}

extension CaptureStatus: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case Self.done.rawValue:
            self = .done
        case Self.inbox.rawValue, "next":
            self = .inbox
        default:
            self = .inbox
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CaptureSourceApplication: Codable, Equatable, Sendable {
    var name: String?
    var bundleIdentifier: String?
    var url: URL?
}

struct CaptureItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    let source: CaptureSource
    var status: CaptureStatus
    let createdAt: Date
    var updatedAt: Date
    var sourceApplication: CaptureSourceApplication?

    init(
        id: UUID = UUID(),
        text: String,
        source: CaptureSource,
        status: CaptureStatus = .inbox,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        sourceApplication: CaptureSourceApplication? = nil
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.sourceApplication = sourceApplication
    }
}
