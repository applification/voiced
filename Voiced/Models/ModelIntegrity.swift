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
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "0b25820e5b2ab0b0686b4bea147fb217d1d1bface45170ff4ffde01fa6864ae2"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "142c33ade402fe41952059f175eb855093dfe09b5d2b84624a31e3a9952ed47d"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 54965, sha256: "030d64a3ddd296d6f709691a66a870aab7ee9f19e5fe07e8086245fb85302802"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 16422784, sha256: "bcd0879f6d1c61832765c7ec05d883d0dcbf1504057b13095fd315484196fc5e"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "5b65b76f4e1dab57239e3946f6ab1314a7d1fdfa114485683dd04476ca62adb6"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "bfbe102ae5fb9368974a077f780441dd222fdfb0c7778c1df227ef6a73cbaada"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "292f96416a33f9a80aaa62ead3dd5206aee6c5e6b3ac6cc02c059d38cbf04c6a"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 113134, sha256: "1afdfc3a8f3e8d6afc46e1ecc5fb216eadccbf82d9c568e7dbd3955143a1cd0e"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 59216434, sha256: "d0313e1a4ffa88538c141cc3c73e6eb0e3dc54db9d574b21c7c034de688e4951"),
            ]
        case .base:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "c4e096b2abd561f00b9b698401df3fbe1a0d0c8d2476ff19cb4e1995680e827e"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "e316980638e2099e83cb1a93b903717dc12b3c2168d0ab69113764c3767696ba"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 79853, sha256: "1d42038f84b508da5ce9b953302387ffedc097c346d36a56b765109002b6080e"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 41189632, sha256: "061ff4d74e5de3937b31288465d6c6f2697f92d121c80b23f51dd26bbdfe642b"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "35d74417ef9c765e70f4ef85fe7405015a7086e9af05e3b63a5c2c7c748b2efc"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "6ac1227740ecc2fd7a03df50ac6e2a7f7946acfa77069cf2c486ae0255356b95"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "9f1f6fe409486e2797d3f0c65d9a6d5af596771760548cd86f41939c54cdbe7c"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 164481, sha256: "ae260ff7b95d0c957c3c1f4df4dbeaa0ae6c76bacc55eb86caca8f6820d346f0"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 104122162, sha256: "72325d42a4a4ccc8a6fa974ede6cdf2e0770685a5c4f9da94f41495b94d8d174"),
            ]
        case .small:
            [
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "211457b92a0ced67bb8625efe39799a0030c4fc71eb87d7284ea81043caccde7"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/coremldata.bin", byteCount: 347, sha256: "d68f152b6573ac55203a3dc8383730e6ecde685c7d2a88815b89820c88e35371"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/model.mlmodel", byteCount: 155271, sha256: "68ca04660b8b050c68ca54c27d97c47e4133bc591422cb7009de8922d56fb8c9"),
                ModelIntegrityFile(relativePath: "AudioEncoder.mlmodelc/weights/weight.bin", byteCount: 176323456, sha256: "fe35cef2c9406993a635639b16f373f6debb0215ac115b7bf93fa03c8e10310b"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "7f77e6457285248f99cd7aa3fd4cc2efbb17733e63e7023ac53abe1f95785d07"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/coremldata.bin", byteCount: 328, sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
                ModelIntegrityFile(relativePath: "MelSpectrogram.mlmodelc/weights/weight.bin", byteCount: 354080, sha256: "267017e533b5f542d195fd9a775f2ba649075128283ce8e86c63a2ec20de5b07"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/analytics/coremldata.bin", byteCount: 243, sha256: "39c0d6d55353bc61ef8071081bb958dd1ab7b0b7f2a3338a797f1a64211e084c"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/coremldata.bin", byteCount: 633, sha256: "b2ccd0b8920701386ab9554f7db47b43e55ee07863280ee5d829d5272839adc2"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/model.mlmodel", byteCount: 313629, sha256: "7ea861c6dfdd866ed0f2e7fe0c3df7459daa44481cb25236e03698dd6d259391"),
                ModelIntegrityFile(relativePath: "TextDecoder.mlmodelc/weights/weight.bin", byteCount: 307287346, sha256: "bfea8044a8f38e8d33f56585b1e75ce023d3845e2a945e20480bd7e16558016e"),
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
