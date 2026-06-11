import EventKit
import Foundation

struct ReminderTask: Equatable {
    let title: String
}

struct ReminderListOption: Identifiable, Equatable {
    let id: String
    let title: String
    let isDefault: Bool
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

    func reminderLists(requestingAccess: Bool) async throws -> [ReminderListOption] {
        if requestingAccess {
            try await requestAccessIfNeeded()
        } else if !hasRemindersAccess {
            return []
        }

        let defaultIdentifier = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        return eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { calendar in
                ReminderListOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    isDefault: calendar.calendarIdentifier == defaultIdentifier
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func exportChecklist(from text: String, to listID: String? = nil) async throws -> Int {
        let tasks = ReminderChecklistParser.tasks(in: text)
        guard !tasks.isEmpty else { throw ReminderExportError.noChecklistItems }

        try await requestAccessIfNeeded()
        guard let calendar = reminderCalendar(for: listID) else {
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

    private var hasRemindersAccess: Bool {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized:
            true
        case .notDetermined, .denied, .restricted, .writeOnly:
            false
        @unknown default:
            false
        }
    }

    private func reminderCalendar(for listID: String?) -> EKCalendar? {
        if let listID,
           let calendar = eventStore.calendars(for: .reminder).first(where: { $0.calendarIdentifier == listID }) {
            return calendar
        }
        return eventStore.defaultCalendarForNewReminders()
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
