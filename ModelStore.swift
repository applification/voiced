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

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localModelURL.path)
    }

    var formattedSize: String {
        guard isDownloaded else { return "Not downloaded" }
        let bytes = directorySize(at: localModelURL)
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    func deleteDownloadedModel() throws {
        guard isDownloaded else { return }
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
}
