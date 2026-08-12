import Foundation
import Observation

@MainActor
@Observable
final class CaptureShelfSelection {
    var status: CaptureStatus = .inbox
    var itemID: UUID?

    func select(_ item: CaptureItem) {
        status = item.status
        itemID = item.id
    }
}
