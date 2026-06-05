import AppKit
import SwiftUI

enum IndicatorState { case recording, transcribing, error(String) }

struct IndicatorView: View {
    let state: IndicatorState

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .recording:
                ProgressView().progressViewStyle(.circular)
                Text("Recording…")
            case .transcribing:
                ProgressView().progressViewStyle(.circular)
                Text("Transcribing…")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(message)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

final class FloatingIndicator {
    private var panel: NSPanel?

    func show(state: IndicatorState) {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                            styleMask: [.borderless],
                            backing: .buffered,
                            defer: false)
            p.isFloatingPanel = true
            p.level = .statusBar
            p.hidesOnDeactivate = false
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = p
        }
        panel?.contentView = NSHostingView(rootView: IndicatorView(state: state))
        panel?.center()
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}
