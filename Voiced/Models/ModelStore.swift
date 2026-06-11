import Foundation

struct ModelStatus: Equatable, Sendable {
    let existsOnDisk: Bool
    let isDownloaded: Bool
    let downloadedBytes: UInt64

    var formattedSize: String {
        guard isDownloaded else { return "Not downloaded" }
        return ByteCountFormatter.string(fromByteCount: Int64(downloadedBytes), countStyle: .file)
    }

    static let missing = ModelStatus(existsOnDisk: false, isDownloaded: false, downloadedBytes: 0)
}

@MainActor
enum ModelStatusCache {
    private static var statuses: [TranscriptionModel: ModelStatus] = [:]
    private static var refreshTasks: [TranscriptionModel: Task<Void, Never>] = [:]

    static func status(for model: TranscriptionModel) -> ModelStatus {
        if let status = statuses[model] {
            return status
        }
        refresh(model)
        return .missing
    }

    static func refresh(_ model: TranscriptionModel) {
        refreshTasks[model]?.cancel()
        refreshTasks[model] = Task {
            let status = await Task.detached(priority: .utility) {
                ModelStore(model: model).statusSnapshot()
            }.value
            guard !Task.isCancelled else { return }
            statuses[model] = status
            refreshTasks[model] = nil
            NotificationCenter.default.post(name: .voicedModelStatusChanged, object: model)
        }
    }

    static func setNeedsRefresh(_ model: TranscriptionModel) {
        statuses[model] = nil
        refresh(model)
    }
}

struct ModelStore: Sendable {
    let model: TranscriptionModel
    let modelRepo = "argmaxinc/whisperkit-coreml"

    var modelName: String {
        model.rawValue
    }

    var localRepoURL: URL {
        downloadBaseURL
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(modelRepo, isDirectory: true)
    }

    var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voiced", isDirectory: true)
    }

    var downloadBaseURL: URL {
        applicationSupportURL
            .appendingPathComponent("huggingface", isDirectory: true)
    }

    var localModelURL: URL {
        localRepoURL
            .appendingPathComponent(model.cacheFolderName, isDirectory: true)
    }

    var existsOnDisk: Bool {
        statusSnapshot().existsOnDisk
    }

    var isDownloaded: Bool {
        statusSnapshot().isDownloaded
    }

    var hasRequiredModelFiles: Bool {
        containsModel(named: "MelSpectrogram")
            && containsModel(named: "AudioEncoder")
            && containsModel(named: "TextDecoder")
    }

    var isPlausiblyComplete: Bool {
        hasRequiredModelFiles
    }

    var formattedSize: String {
        statusSnapshot().formattedSize
    }

    var downloadedBytes: UInt64 {
        statusSnapshot().downloadedBytes
    }

    func deleteDownloadedModel() throws {
        guard existsOnDisk else { return }
        try FileManager.default.removeItem(at: localModelURL)
    }

    func prepareStorageForDownload() throws {
        try FileManager.default.createDirectory(at: downloadBaseURL, withIntermediateDirectories: true)
    }

    func statusSnapshot() -> ModelStatus {
        let exists = FileManager.default.fileExists(atPath: localModelURL.path)
        let downloaded = hasRequiredModelFiles
        let bytes = downloaded ? directorySize(at: localModelURL) : 0
        return ModelStatus(existsOnDisk: exists, isDownloaded: downloaded, downloadedBytes: bytes)
    }

    private func directorySize(at url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let fileSize = values.fileSize
            else {
                continue
            }
            total += UInt64(fileSize)
        }
        return total
    }

    private func containsModel(named modelName: String) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: localModelURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            let name = fileURL.deletingPathExtension().lastPathComponent
            guard name == modelName else { continue }
            let ext = fileURL.pathExtension
            if ext == "mlmodelc" || ext == "mlpackage" {
                return true
            }
        }
        return false
    }
}
