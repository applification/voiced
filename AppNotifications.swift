import Foundation

extension Notification.Name {
    static let voicedModelApprovalChanged = Notification.Name("voicedModelApprovalChanged")
    static let voicedModelLoadProgressChanged = Notification.Name("voicedModelLoadProgressChanged")
}

enum ModelLoadProgressInfoKey {
    static let modelRawValue = "modelRawValue"
    static let modelLabel = "modelLabel"
    static let fractionCompleted = "fractionCompleted"
    static let phase = "phase"
}
