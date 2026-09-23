import AppKit
import HintjumpCore

/// The `NSPasteboard.general`-backed adapter for ``HintjumpCore/PasteboardWriting``.
///
/// Translation only: it clears the pasteboard and puts `text` on it as a plain string,
/// the one type every app that pastes a path accepts.
public struct GeneralPasteboardWriter: PasteboardWriting {
    public init() {
        // Stateless: NSPasteboard.general is the whole dependency.
    }

    /// Replaces the general pasteboard's contents with `text`.
    ///
    /// The Bool `setString` answers is dropped, as ``WorkspaceConfigFileOpener`` drops
    /// its outcome: a failed copy leaves the old contents, which the user sees on the
    /// next paste, and no Core state would change on it.
    public func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
