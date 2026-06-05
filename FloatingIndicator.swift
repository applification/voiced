import AppKit
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
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(minWidth: 170, minHeight: 33)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
            .fill(.black)
        }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0
            )
            .strokeBorder(.white.opacity(0.08))
        }
        .fixedSize()
    }

    @ViewBuilder
    private var rowContent: some View {
        switch state {
        case .recording(let level):
                WaveformView(level: level, color: waveformColor)
                    .frame(width: 104, height: 20)
                Circle()
                    .fill(waveformColor)
                    .frame(width: 5, height: 5)
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
    private var panel: NSPanel?
    private var notchGeometry: NotchGeometry?
    private var isVisible = false

    func show(state: IndicatorState) {
        let panel = existingOrCreatePanel()
        notchGeometry = Self.detectNotchGeometry()
        let isNotched = notchGeometry != nil
        let rootView = isNotched
            ? AnyView(NotchContentView(state: state))
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
        let size = panel.contentView?.fittingSize ?? NSSize(width: geometry.width, height: 46)
        let width = max(size.width, geometry.width)
        let height = size.height
        panel.setContentSize(NSSize(width: width, height: height))

        let visibleY = geometry.visibleOriginY(forHeight: height)
        let hiddenY = geometry.hiddenOriginY
        let origin = NSPoint(
            x: geometry.centerX - width / 2,
            y: visible ? visibleY : hiddenY
        )
        panel.setFrameOrigin(origin)
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
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        guard let screen, screen.safeAreaInsets.top > 0 else { return nil }

        let frame = screen.frame
        let leftArea = screen.auxiliaryTopLeftArea
        let rightArea = screen.auxiliaryTopRightArea
        let centerX: CGFloat
        let width: CGFloat

        if let leftArea, let rightArea, !leftArea.isEmpty, !rightArea.isEmpty {
            centerX = (leftArea.maxX + rightArea.minX) / 2 + 1
            width = max(170, rightArea.minX - leftArea.maxX - 16)
        } else {
            centerX = frame.midX + 1
            width = 170
        }

        return NotchGeometry(
            screenFrame: frame,
            centerX: centerX,
            width: width,
            topInset: screen.safeAreaInsets.top
        )
    }
}

private struct NotchGeometry {
    let screenFrame: NSRect
    let centerX: CGFloat
    let width: CGFloat
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
