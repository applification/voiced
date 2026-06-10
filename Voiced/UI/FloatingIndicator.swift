import AppKit
import os
import SwiftUI

@MainActor
final class FloatingIndicator {
    private static let logger = Logger(subsystem: "net.applification.voiced", category: "indicator")

    private var panel: NSPanel?
    private var notchGeometry: NotchGeometry?
    private var isVisible = false
    private var visibilityGeneration = 0

    func show(state: IndicatorState) {
        visibilityGeneration += 1
        Self.logger.info("Indicator show state=\(String(describing: state), privacy: .public) generation=\(self.visibilityGeneration, privacy: .public)")
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
        visibilityGeneration += 1
        let generation = visibilityGeneration
        Self.logger.info("Indicator hide generation=\(generation, privacy: .public)")
        isVisible = false
        if notchGeometry != nil {
            animateNotch(panel, visible: false)
        } else {
            panel.orderOut(nil)
        }
        tearDownContent(for: generation, panel: panel)
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

    private func tearDownContent(for generation: Int, panel: NSPanel) {
        guard generation == visibilityGeneration, !isVisible else { return }
        panel.orderOut(nil)
        panel.contentView = nil
    }

    private func animateNotch(_ panel: NSPanel, visible: Bool) {
        guard let notchGeometry else {
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
