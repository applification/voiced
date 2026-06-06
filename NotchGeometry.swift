import AppKit

struct NotchIndicatorMetrics {
    let width: CGFloat
    let height: CGFloat

    static let fallback = NotchIndicatorMetrics(width: 154, height: 28)

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

    static func from(notchGap: CGFloat, topInset: CGFloat) -> NotchIndicatorMetrics {
        let gapFittedWidth = notchGap * 0.86
        let width = max(118, min(166, gapFittedWidth))
        let insetFittedHeight = topInset * 0.86
        let height = max(24, min(30, insetFittedHeight))
        return NotchIndicatorMetrics(width: width, height: height)
    }
}

struct NotchGeometry {
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
