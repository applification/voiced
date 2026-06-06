import SwiftUI

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
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
