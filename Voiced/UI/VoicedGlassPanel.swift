import SwiftUI

extension View {
    @ViewBuilder
    func voicedGlassPanel(cornerRadius: CGFloat, tint: LinearGradient) -> some View {
        if #available(macOS 26.0, *) {
            self
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                }
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                }
        }
    }
}
