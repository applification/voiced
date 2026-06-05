import AppKit
import os
import SwiftUI

enum IndicatorState {
    case recording(level: Double)
    case loadingModel(String)
    case transcribing
    case error(String)
}

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
    fileprivate var indicatorContent: some View {
        HStack(spacing: 10) {
            switch state {
            case .recording(let level):
                WaveformView(level: level, color: waveformColor)
                    .frame(width: 108, height: 24)
                Circle()
                    .fill(waveformColor)
                    .frame(width: 6, height: 6)
            case .loadingModel(let model):
                ProgressView()
                    .controlSize(.small)
                    .progressViewStyle(.circular)
                    .tint(waveformColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Loading model")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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

private struct NotchContentView: View {
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
        case .loadingModel(let model):
                NotchSpinnerView(color: waveformColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Loading model")
                        .font(.caption)
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
        case .transcribing:
            EmptyView()
        case .error:
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
        }
    }
}

private struct NotchIndicatorMetrics {
    let width: CGFloat
    let height: CGFloat

    var horizontalPadding: CGFloat {
        max(9, min(14, width * 0.075))
    }

    var cornerRadius: CGFloat {
        max(11, min(15, height * 0.48))
    }

    var waveformWidth: CGFloat {
        max(78, width - horizontalPadding * 2 - 26)
    }

    var waveformHeight: CGFloat {
        max(15, height - 12)
    }

    var dotSize: CGFloat {
        max(4, min(5, height * 0.15))
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

private struct NotchSpinnerView: View {
    let color: Color

    @State private var rotation = 0.0

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .frame(width: 14, height: 14)
    }
}

private struct WaveformView: View {
    let level: Double
    let color: Color

    private let barCount = 18

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let spacing = size.width / CGFloat(barCount)
                let lineWidth = min(3, spacing * 0.44)
                let baseHeight = size.height * 0.16
                let activeHeight = size.height * (0.24 + 0.72 * CGFloat(level))
                let centerY = size.height / 2

                for index in 0..<barCount {
                    let phase = time * 5 + Double(index) * 0.58
                    let wave = (sin(phase) + 1) / 2
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
}

@MainActor
final class FloatingIndicator {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "indicator")

    private var panel: NSPanel?
    private var notchGeometry: NotchGeometry?
    private var isVisible = false

    func show(state: IndicatorState) {
        let panel = existingOrCreatePanel()
        notchGeometry = Self.detectNotchGeometry()
        let isNotched = notchGeometry != nil
        let rootView = isNotched
            ? AnyView(NotchContentView(state: state, metrics: notchGeometry?.metrics ?? .fallback))
            : AnyView(IndicatorView(state: state))
        let hostingView = TransparentHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        panel.contentView = hostingView
        position(panel, visible: isVisible || !isNotched)
        panel.orderFrontRegardless()
        if isNotched && !isVisible {
            animateNotch(panel, visible: true)
        }
        isVisible = true
    }

    func hide() {
        guard let panel else { return }
        if notchGeometry != nil {
            animateNotch(panel, visible: false) {
                panel.orderOut(nil)
            }
        } else {
            panel.orderOut(nil)
        }
        isVisible = false
    }

    private func existingOrCreatePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 156, height: 44),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentViewController = nil
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.isOpaque = false
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, visible: Bool = true) {
        if let notchGeometry {
            positionNotch(panel, geometry: notchGeometry, visible: visible)
            return
        }

        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        guard let frame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.contentView?.fittingSize ?? NSSize(width: 156, height: 44)
        panel.setContentSize(size)
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + min(120, frame.height * 0.18)
        )
        panel.setFrameOrigin(origin)
    }

    private func positionNotch(_ panel: NSPanel, geometry: NotchGeometry, visible: Bool) {
        let width = geometry.metrics.width
        let height = geometry.metrics.height
        panel.setContentSize(NSSize(width: width, height: height))

        let visibleY = geometry.visibleOriginY(forHeight: height)
        let hiddenY = geometry.hiddenOriginY
        let origin = NSPoint(
            x: geometry.centerX - width / 2,
            y: visible ? visibleY : hiddenY
        )
        panel.setFrameOrigin(origin)
        Self.logger.info("Notch indicator frame origin=(\(origin.x, privacy: .public), \(origin.y, privacy: .public)) size=(\(width, privacy: .public), \(height, privacy: .public)) centerX=\(geometry.centerX, privacy: .public) screen=\(String(describing: geometry.screenFrame), privacy: .public)")
    }

    private func animateNotch(_ panel: NSPanel, visible: Bool, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let notchGeometry else {
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: visible ? .easeOut : .easeIn)
            let size = panel.frame.size
            let y = visible
                ? notchGeometry.visibleOriginY(forHeight: size.height)
                : notchGeometry.hiddenOriginY
            let frame = NSRect(
                x: notchGeometry.centerX - size.width / 2,
                y: y,
                width: size.width,
                height: size.height
            )
            panel.animator().setFrame(frame, display: true)
        } completionHandler: {
            Task { @MainActor in
                completion?()
            }
        }
    }

    private static func detectNotchGeometry() -> NotchGeometry? {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSApp.keyWindow?.screen
            ?? NSScreen.main
        guard let screen, screen.safeAreaInsets.top > 0 else { return nil }

        let frame = screen.frame
        let leftArea = screen.auxiliaryTopLeftArea
        let rightArea = screen.auxiliaryTopRightArea
        let centerX = frame.midX
        let metrics: NotchIndicatorMetrics

        if let leftArea, let rightArea, !leftArea.isEmpty, !rightArea.isEmpty {
            let notchGap = max(0, rightArea.minX - leftArea.maxX)
            metrics = NotchIndicatorMetrics.from(notchGap: notchGap, topInset: screen.safeAreaInsets.top)
        } else {
            metrics = .fallback
        }

        logger.info("Detected notch screen frame=\(String(describing: frame), privacy: .public) visible=\(String(describing: screen.visibleFrame), privacy: .public) safeTop=\(screen.safeAreaInsets.top, privacy: .public) left=\(String(describing: leftArea), privacy: .public) right=\(String(describing: rightArea), privacy: .public) centerX=\(centerX, privacy: .public) width=\(metrics.width, privacy: .public) height=\(metrics.height, privacy: .public)")

        return NotchGeometry(
            screenFrame: frame,
            centerX: centerX,
            metrics: metrics,
            topInset: screen.safeAreaInsets.top
        )
    }
}

private extension NotchIndicatorMetrics {
    static let fallback = NotchIndicatorMetrics(width: 154, height: 28)

    static func from(notchGap: CGFloat, topInset: CGFloat) -> NotchIndicatorMetrics {
        let gapFittedWidth = notchGap * 0.86
        let width = max(118, min(166, gapFittedWidth))
        let insetFittedHeight = topInset * 0.86
        let height = max(24, min(30, insetFittedHeight))
        return NotchIndicatorMetrics(width: width, height: height)
    }
}

private struct NotchGeometry {
    let screenFrame: NSRect
    let centerX: CGFloat
    let metrics: NotchIndicatorMetrics
    let topInset: CGFloat

    var hiddenOriginY: CGFloat {
        screenFrame.maxY - 4
    }

    func visibleOriginY(forHeight height: CGFloat) -> CGFloat {
        screenFrame.maxY - topInset - height + 4
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        get { false }
        set {}
    }

    override var wantsDefaultClipping: Bool {
        false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
}
