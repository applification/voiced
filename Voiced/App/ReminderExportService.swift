import EventKit
import Foundation

struct ReminderTask: Equatable {
    let title: String
}

enum ReminderExportResult {
    case success(count: Int)
    case failure(String)
}

enum ReminderExportError: LocalizedError {
    case noChecklistItems
    case remindersAccessDenied
    case missingDefaultList

    var errorDescription: String? {
        switch self {
        case .noChecklistItems:
            "No checklist items found."
        case .remindersAccessDenied:
            "Reminders access is not allowed."
        case .missingDefaultList:
            "No default Reminders list is available."
        }
    }
}

enum ReminderChecklistParser {
    static func tasks(in text: String) -> [ReminderTask] {
        text.split(whereSeparator: \.isNewline)
            .compactMap { task(from: String($0)) }
    }

    static func taskCount(in text: String) -> Int {
        tasks(in: text).count
    }

    private static func task(from line: String) -> ReminderTask? {
        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let checklistPrefixes = ["- [ ]", "* [ ]", "+ [ ]", "- [x]", "* [x]", "+ [x]", "- [X]", "* [X]", "+ [X]"]
        guard let prefix = checklistPrefixes.first(where: { trimmed.hasPrefix($0) }) else { return nil }
        trimmed.removeFirst(prefix.count)
        let title = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        guard title.localizedCaseInsensitiveCompare("No clear tasks captured") != .orderedSame else { return nil }
        return ReminderTask(title: title)
    }
}

@MainActor
final class ReminderExportService {
    private let eventStore = EKEventStore()

    func checklistItemCount(in text: String) -> Int {
        ReminderChecklistParser.taskCount(in: text)
    }

    func exportChecklist(from text: String) async throws -> Int {
        let tasks = ReminderChecklistParser.tasks(in: text)
        guard !tasks.isEmpty else { throw ReminderExportError.noChecklistItems }

        try await requestAccessIfNeeded()
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw ReminderExportError.missingDefaultList
        }

        do {
            for task in tasks {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.title = task.title
                reminder.calendar = calendar
                try eventStore.save(reminder, commit: false)
            }
            try eventStore.commit()
            return tasks.count
        } catch {
            eventStore.reset()
            throw error
        }
    }

    private func requestFullAccessToReminders() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func requestAccessIfNeeded() async throws {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized:
            return
        case .notDetermined:
            let granted = try await requestFullAccessToReminders()
            guard granted else { throw ReminderExportError.remindersAccessDenied }
        case .denied, .restricted, .writeOnly:
            throw ReminderExportError.remindersAccessDenied
        @unknown default:
            throw ReminderExportError.remindersAccessDenied
        }
    }
}
