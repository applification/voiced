import CryptoKit
import Foundation

struct ModelIntegrityFile {
    let relativePath: String
    let byteCount: UInt64
    let sha256: String
}

enum ModelIntegrityError: LocalizedError {
    case missingManifest(String)
    case missingFile(String)
    case sizeMismatch(path: String, expected: UInt64, actual: UInt64)
    case checksumMismatch(path: String)

    var errorDescription: String? {
        switch self {
        case .missingManifest(let model):
            "No integrity manifest is bundled for model '\(model)'."
        case .missingFile(let path):
            "Model verification failed because '\(path)' is missing."
        case .sizeMismatch(let path, let expected, let actual):
            "Model verification failed for '\(path)': expected \(expected) bytes, found \(actual)."
        case .checksumMismatch(let path):
            "Model verification failed because '\(path)' did not match its expected checksum."
        }
    }
}

enum ModelIntegrity {
    static func verify(model: TranscriptionModel, at modelURL: URL) throws {
        guard let manifest = manifest(for: model) else {
            throw ModelIntegrityError.missingManifest(model.rawValue)
        }

        for file in manifest {
            let url = modelURL.appendingPathComponent(file.relativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ModelIntegrityError.missingFile(file.relativePath)
            }

            let actualByteCount = try byteCount(at: url)
            guard actualByteCount == file.byteCount else {
                throw ModelIntegrityError.sizeMismatch(
                    path: file.relativePath,
                    expected: file.byteCount,
                    actual: actualByteCount
                )
            }

            let actualHash = try sha256HexDigest(at: url)
            guard actualHash == file.sha256 else {
                throw ModelIntegrityError.checksumMismatch(path: file.relativePath)
            }
        }
    }

    private static func byteCount(at url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values.fileSize ?? 0)
    }

    private static func sha256HexDigest(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1_048_576)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func manifest(for model: TranscriptionModel) -> [ModelIntegrityFile]? {
        switch model {
        case .tiny:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "eaaaa6671a96a359a0bbd5e97885246dcc17f7435b6ffad8d871bb940964500b"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "325b182d0a4266730a81795ae6b7a787b5111dd091500fc0c04dedf610015d46"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 54965, sha256: "030d64a3ddd296d6f709691a66a870aab7ee9f19e5fe07e8086245fb85302802"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 16422784, sha256: "f3706dac8d9d4bec269d3cee10fa4eda39b4240a46091c8323c1731a8c6d59c2"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "160d9737169d22dc01a899e1c6a0a9c44d0637d41f0dedb2a0b7c1422c4035d2"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "cb3b3f51b080f58b12a6888a5e8ad57419be9e4c6843b96a7577f171b300e660"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "801024dbc7a89c677be1f8b285de3409e35f7d1786c9c8d9d0d6842ac57a1c83"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "edb99a30ccee8e157fbec80dc3dce49349ba0982391b327d753e10ccab0a01c3"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "65c043a081845d190918b4c7d244f94a55df1a15fae796abedc1f414995542c6"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 108558, sha256: "5c3e91bc036014426708e2ceb0e35cb1bbbf34e8121d2070d2b174a7957581d0"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 59215664, sha256: "763f915f0126093fc2c506572b3ab0fad134c04cfc2221333ccc7d73552c9252"),
            ]
        case .base:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "c4e096b2abd561f00b9b698401df3fbe1a0d0c8d2476ff19cb4e1995680e827e"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "e316980638e2099e83cb1a93b903717dc12b3c2168d0ab69113764c3767696ba"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 79853, sha256: "1d42038f84b508da5ce9b953302387ffedc097c346d36a56b765109002b6080e"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 41189632, sha256: "74f15e6d2f7694af54e90227cbf22fd6c04082638f163b78a909967b16edc1c7"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "ee77f9b67765f7abc33f16374081b2389cf1d3a89536187b241950c5a2e5d6c1"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "e870aac5de88676c1ad93cb3939f257e6de30e5235c3f9d7686398ebecafdb8d"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "4b23ff9d9fe376f2b86f9cf55af3218560a4e4d692041360510fbad490c0db43"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 160348, sha256: "72f1214f7c8b26e467dd8233572eaa5cbe200f30a36b918d4c289f9fc8c4f401"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 104121136, sha256: "4649599bd2d97f87ffc716e6da2f61a06c06ac5a9424dd23edc3d4bf66fb6221"),
            ]
        case .small:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "211457b92a0ced67bb8625efe39799a0030c4fc71eb87d7284ea81043caccde7"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "d8be820f6e3406891bdd25effc0e3b4cac712064c8bcf74053d8abec7e97c585"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 155271, sha256: "68ca04660b8b050c68ca54c27d97c47e4133bc591422cb7009de8922d56fb8c9"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 176323456, sha256: "f92860042703b3679071e7eeb03c861e52bf0e1da38943cf7c37eb5fecfb3abe"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "50b463279c2f0089cd82a82f6c091675c6d499515562067c47c706f59051e4a0"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "63c717108d44630649d42e255ac94739c725937bf8e16ae6787e04c3a4f0ec6a"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "f596a022005761b7f18e448b6c34be2b6f6a2797d11371145e4544eb25fa411d"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 326032, sha256: "702d2df1b6a37b49a4e21f8024c230148e3b0f7c6c4e9001deb5501b496971f2"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 307285808, sha256: "a71a58c723a8c379fbc0ba666d6a3d3dd85d84d34ee8665697d2edab52f2f6b1"),
            ]
        case .largeAccuracy:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "56793886ab1adb9ca8a4e335efbe8af6640f40d958ab2d29c3ad2d7d6f712e95"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 348, sha256: "ffa9eb76e8e9d9be75a4d527e5249e61d67fd43081c5aa110fd24efa6c8c5ea3"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 421968768, sha256: "e4740fa28ed65907af754af893dfce98473fafb84dd8d718ad346985fe7678c1"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "c5be419f8622083ac7046306400643539f0e7577c843448c36defc090d41e7ce"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 329, sha256: "2bfc12cffc2e45e039c7a18f384f09adffb72c182fcd93f9413d405d1a6c1130"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 373376, sha256: "009d9fb8f6b589accfa08cebf1c712ef07c3405229ce3cfb3a57ee033c9d8a49"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "3913b8c9716b284a917cf3744f4d415f2a05e2b910594a14c6cc10092284d3f8"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "3faabaf66930e66956d8291d0ff485fb382496e30a91a7185548b9b898ce90a9"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 203199860, sha256: "d69700903d518ada33170ab77faaaf464496fb9ff65752c6d5a6109aa2fb02db"),
            ]
        }
    }
}
