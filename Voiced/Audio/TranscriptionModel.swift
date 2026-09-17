import CoreML
import SwiftUI
import WhisperKit

enum TranscriptionModel: String, CaseIterable, Identifiable, Sendable {
    case parakeetV2 = "parakeet-v2-english"
    case tiny
    case base
    case small
    case largeAccuracy = "large-v3-v20240930_626MB"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parakeetV2: "Parakeet v2 English"
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largeAccuracy: "Large v3 Turbo"
        }
    }

    var detail: String {
        switch self {
        case .parakeetV2: "English · Apple Silicon"
        case .tiny: "Fastest"
        case .base: "Fast"
        case .small: "Balanced"
        case .largeAccuracy: "Most accurate"
        }
    }

    var onboardingSubtitle: String {
        switch self {
        case .parakeetV2: "Recommended for English"
        case .tiny: "Quick first run"
        case .base: "Still light, clearer"
        case .small: "Better everyday accuracy"
        case .largeAccuracy: "Best quality option"
        }
    }

    var onboardingDetail: String {
        switch self {
        case .parakeetV2: "Local speech + vocabulary"
        case .tiny: "Fastest first run"
        case .base: "Fast and clearer"
        case .small: "Balanced accuracy"
        case .largeAccuracy: "Most accurate"
        }
    }

    var downloadSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(expectedDownloadBytes), countStyle: .file)
    }

    var symbolName: String {
        switch self {
        case .parakeetV2: "waveform"
        case .tiny: "hare.fill"
        case .base: "bolt.fill"
        case .small: "scale.3d"
        case .largeAccuracy: "sparkles"
        }
    }

    var tintColor: Color {
        switch self {
        case .parakeetV2: .mint
        case .tiny: .green
        case .base: .blue
        case .small: .indigo
        case .largeAccuracy: .purple
        }
    }

    var menuTitle: String {
        "\(label) (\(detail))"
    }

    var whisperKitVariant: String {
        switch self {
        case .parakeetV2: rawValue
        case .tiny: "tiny.en"
        case .base: "base.en"
        case .small: "small.en"
        case .largeAccuracy: rawValue
        }
    }

    var cacheFolderName: String {
        "openai_whisper-\(whisperKitVariant)"
    }

    var expectedDownloadBytes: UInt64 {
        switch self {
        case .parakeetV2: 550 * 1_024 * 1_024
        case .tiny: 73 * 1_024 * 1_024
        case .base: 143 * 1_024 * 1_024
        case .small: 479 * 1_024 * 1_024
        case .largeAccuracy: 626 * 1_024 * 1_024
        }
    }

    var modelComputeOptions: ModelComputeOptions {
        switch self {
        case .tiny, .parakeetV2:
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
