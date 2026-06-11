import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioLevelModel {
    var level: Double = 0
}

@MainActor
@Observable
final class IndicatorPresentationModel {
    var state: IndicatorState = .recording(level: 0)
    let audioLevel = AudioLevelModel()
}

enum IndicatorContentMode {
    case floating
    case notch
}

struct IndicatorView: View {
    let model: IndicatorPresentationModel

    private var state: IndicatorState { model.state }
    private var audioLevel: Double { model.audioLevel.level }

    private let waveformColor = Color(red: 0.48, green: 0.78, blue: 0.56)
    private let pillFill = Color(nsColor: .controlBackgroundColor).opacity(0.94)

    var body: some View {
        indicatorContent
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 132, minHeight: 38)
            .background {
                Capsule()
                    .fill(pillFill)
            }
            .overlay {
                Capsule().strokeBorder(.primary.opacity(0.1))
            }
            .fixedSize()
    }

    @ViewBuilder
    private var indicatorContent: some View {
        HStack(spacing: 10) {
            switch state {
            case .recording:
                LevelWaveformView(level: audioLevel, color: waveformColor)
                    .frame(width: 108, height: 24)
                LivePulseDot(color: waveformColor, size: 6)
            case .transcribing:
                Text("Transcribing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .processing:
                Text("Processing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .success(let message):
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(waveformColor)
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            case .error(let message):
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct NotchContentView: View {
    let model: IndicatorPresentationModel
    let metrics: NotchIndicatorMetrics

    private var state: IndicatorState { model.state }
    private var audioLevel: Double { model.audioLevel.level }

    private let waveformColor = Color(red: 0.48, green: 0.78, blue: 0.56)

    var body: some View {
        Group {
            if state.isTextProgress {
                HStack(spacing: 8) {
                    NotchTranscribingIcon(color: waveformColor)
                    Text(state.progressTitle)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(spacing: 10) {
                    rowContent
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 3)
        .padding(.bottom, 4)
        .frame(width: metrics.width, height: metrics.height)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: metrics.cornerRadius,
                bottomTrailingRadius: metrics.cornerRadius,
                topTrailingRadius: 0
            )
            .fill(.black)
        }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: metrics.cornerRadius,
                bottomTrailingRadius: metrics.cornerRadius,
                topTrailingRadius: 0
            )
            .strokeBorder(.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        switch state {
        case .recording:
            LevelWaveformView(level: audioLevel, color: waveformColor)
                .frame(width: metrics.waveformWidth, height: metrics.waveformHeight)
            LivePulseDot(color: waveformColor, size: metrics.dotSize)
        case .transcribing, .processing:
            EmptyView()
        case .success(let message):
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(waveformColor)
            Text(message)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        case .error(let message):
            Image(systemName: "exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct NotchTranscribingIcon: View {
    let color: Color

    @State private var pulse = false

    var body: some View {
        Image(systemName: "waveform")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .scaleEffect(pulse ? 1.16 : 0.92)
            .opacity(pulse ? 1 : 0.58)
            .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: pulse)
            .onAppear {
                pulse = true
            }
            .frame(width: 14, height: 14)
    }
}

struct LevelWaveformView: View {
    let level: Double
    let color: Color

    private let multipliers: [CGFloat] = [0.48, 0.72, 0.56, 1.0, 0.64, 0.84, 0.52]

    var body: some View {
        GeometryReader { proxy in
            let rawLevel = max(0, min(1, CGFloat(level)))
            let normalizedLevel = rawLevel == 0 ? 0.16 : max(0.16, pow(rawLevel, 0.5))
            let barWidth = min(3, max(2, proxy.size.width * 0.075))
            let minimumHeight = max(3, proxy.size.height * 0.22)
            let availableHeight = max(0, proxy.size.height - minimumHeight)

            HStack(alignment: .center, spacing: max(2, barWidth * 0.8)) {
                ForEach(multipliers.indices, id: \.self) { index in
                    let multiplier = multipliers[index]
                    let barHeight = minimumHeight + availableHeight * normalizedLevel * multiplier
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(color.opacity(0.42 + 0.58 * normalizedLevel))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .animation(.easeOut(duration: 0.045), value: level)
        }
    }
}

private struct LivePulseDot: View {
    let color: Color
    let size: CGFloat

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.35 : 0.72)
            .opacity(isPulsing ? 0.45 : 1)
            .animation(.easeOut(duration: 0.62).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}
