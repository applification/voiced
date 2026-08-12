import SwiftUI

enum VoicedShelfStyle {
    static let signalMint = Color(red: 0.53, green: 0.82, blue: 0.63)
    static let surfaceRadius: CGFloat = 14
}

extension View {
    @ViewBuilder
    func voicedGlassSurface(
        cornerRadius: CGFloat = VoicedShelfStyle.surfaceRadius,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(
                    .regular.tint(tint).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                self.glassEffect(
                    .regular.tint(tint),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            self
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    func voicedGlassButton(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else if let tint {
                self.buttonStyle(.glass(.regular.tint(tint)))
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func voicedGlassGroup(spacing: CGFloat = 8) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func voicedWindowMaterial() -> some View {
        if #available(macOS 15.0, *) {
            self.containerBackground(.thickMaterial, for: .window)
        } else {
            self.background(.regularMaterial)
        }
    }

    func voicedWorkspacePane() -> some View {
        self.background {
            ZStack {
                Rectangle()
                    .fill(.thickMaterial)
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.74))
            }
            .ignoresSafeArea()
        }
    }
}
