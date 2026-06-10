import AppKit
import SwiftUI

struct IndicatorView: View {
    let state: IndicatorState

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
            case .recording(let level):
                WaveformView(level: level, color: waveformColor)
                    .frame(width: 108, height: 24)
                Circle()
                    .fill(waveformColor)
                    .frame(width: 6, height: 6)
            case .transcribing:
                Text("Transcribing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .error:
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
            }
        }
    }
}

struct NotchContentView: View {
    let state: IndicatorState
    let metrics: NotchIndicatorMetrics

    private let waveformColor = Color(red: 0.48, green: 0.78, blue: 0.56)

    var body: some View {
        Group {
            if case .transcribing = state {
                HStack(spacing: 8) {
                    NotchTranscribingIcon(color: waveformColor)
                    Text("Transcribing")
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
        case .recording(let level):
            WaveformView(level: level, color: waveformColor)
                .frame(width: metrics.waveformWidth, height: metrics.waveformHeight)
            Circle()
                .fill(waveformColor)
                .frame(width: metrics.dotSize, height: metrics.dotSize)
        case .transcribing:
            EmptyView()
        case .error:
            Image(systemName: "exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
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

private struct WaveformView: View {
    let level: Double
    let color: Color

    private let barCount = 18

    var body: some View {
        Canvas { context, size in
            let spacing = size.width / CGFloat(barCount)
            let lineWidth = min(3, spacing * 0.44)
            let baseHeight = size.height * 0.16
            let activeHeight = size.height * (0.24 + 0.72 * CGFloat(level))
            let centerY = size.height / 2

            for index in 0..<barCount {
                let wave = (sin(Double(index) * 0.76 + level * 2.4) + 1) / 2
                let stagger = 0.55 + 0.45 * wave
                let height = max(baseHeight, activeHeight * CGFloat(stagger))
                let x = CGFloat(index) * spacing + spacing / 2
                let rect = CGRect(
                    x: x - lineWidth / 2,
                    y: centerY - height / 2,
                    width: lineWidth,
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: lineWidth / 2)
                let opacity = 0.36 + 0.64 * CGFloat(level)
                context.fill(path, with: .color(color.opacity(opacity)))
            }
        }
    }
}
