import CoreML
import WhisperKit

enum TranscriptionModel: String, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case largeAccuracy = "large-v3-v20240930_626MB"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largeAccuracy: "Large v3"
        }
    }

    var detail: String {
        switch self {
        case .tiny: "Fastest"
        case .base: "Fast"
        case .small: "Balanced"
        case .largeAccuracy: "Most accurate"
        }
    }

    var menuTitle: String {
        "\(label) (\(detail))"
    }

    var cacheFolderName: String {
        "openai_whisper-\(rawValue)"
    }

    var expectedDownloadBytes: UInt64 {
        switch self {
        case .tiny: 73 * 1_024 * 1_024
        case .base: 143 * 1_024 * 1_024
        case .small: 479 * 1_024 * 1_024
        case .largeAccuracy: 626 * 1_024 * 1_024
        }
    }

    var modelComputeOptions: ModelComputeOptions {
        switch self {
        case .tiny:
            ModelComputeOptions()
        case .base, .small, .largeAccuracy:
            ModelComputeOptions(
                melCompute: .cpuAndGPU,
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
        }
    }
}
