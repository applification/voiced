import SwiftUI

enum CaptureRelativeTimeLabel {
    static func text(for date: Date, relativeTo now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        switch elapsed {
        case ..<60:
            return "Now"
        case ..<3_600:
            return "\(max(1, Int(elapsed / 60)))m"
        case ..<86_400:
            return "\(Int(elapsed / 3_600))h"
        case ..<604_800:
            return "\(Int(elapsed / 86_400))d"
        default:
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    static func accessibilityText(for date: Date, relativeTo now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        switch elapsed {
        case ..<60:
            return "Updated less than a minute ago"
        case ..<3_600:
            let minutes = max(1, Int(elapsed / 60))
            return "Updated \(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
        case ..<86_400:
            let hours = Int(elapsed / 3_600)
            return "Updated \(hours) \(hours == 1 ? "hour" : "hours") ago"
        case ..<604_800:
            let days = Int(elapsed / 86_400)
            return "Updated \(days) \(days == 1 ? "day" : "days") ago"
        default:
            return "Updated \(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

struct CaptureRelativeTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(CaptureRelativeTimeLabel.text(for: date, relativeTo: context.date))
                .accessibilityLabel(
                    CaptureRelativeTimeLabel.accessibilityText(for: date, relativeTo: context.date)
                )
        }
    }
}
