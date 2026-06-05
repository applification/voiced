import AppKit

enum OutputBehavior {
    case clipboardPaste
    case copyOnly
}

final class OutputManager {
    func performOutput(_ text: String, behavior: OutputBehavior) {
        switch behavior {
        case .clipboardPaste:
            pastePreservingClipboard(text)
        case .copyOnly:
            copyToClipboard(text)
        }
    }

    func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func pastePreservingClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let previousItems = pb.pasteboardItems
        pb.clearContents()
        pb.setString(text, forType: .string)

        postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if let items = previousItems, !items.isEmpty {
                pb.writeObjects(items.compactMap { $0 })
            }
        }
    }

    private func postCommandV() {
        let vKey: CGKeyCode = 9 // ANSI 'v'
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
