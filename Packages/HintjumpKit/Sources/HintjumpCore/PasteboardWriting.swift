/// A port: put text on the general pasteboard.
///
/// `NSPasteboard` is AppKit, which Core may not import (`docs/architecture.md` ›
/// Layers). The Config File pane's "Copy Path" is the only caller, so the port is one
/// method deep, like ``SystemSettingsOpening``.
@MainActor
public protocol PasteboardWriting: Sendable {
    /// Replaces the pasteboard's contents with `text`.
    func copy(_ text: String)
}
