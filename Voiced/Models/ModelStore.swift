import Foundation

@MainActor
struct ModelStore {
    let model: TranscriptionModel
    let modelRepo = "argmaxinc/whisperkit-coreml"

    var modelName: String {
        model.rawValue
    }

    var localRepoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(modelRepo, isDirectory: true)
    }

    var localModelURL: URL {
        localRepoURL
            .appendingPathComponent(model.cacheFolderName, isDirectory: true)
    }

    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: localModelURL.path)
    }

    var isDownloaded: Bool {
        hasRequiredModelFiles
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
        guard isDownloaded else { return "Not downloaded" }
        let bytes = downloadedBytes
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var downloadedBytes: UInt64 {
        directorySize(at: localModelURL)
    }

    func deleteDownloadedModel() throws {
        guard existsOnDisk else { return }
        try FileManager.default.removeItem(at: localModelURL)
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
