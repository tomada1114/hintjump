import AppKit
import HintjumpCore
import UniformTypeIdentifiers

/// The `NSWorkspace`-backed adapter for ``HintjumpCore/ConfigFileOpening``: the editor
/// for "Open", Finder for "Reveal in Finder".
///
/// Opens the file in the user's default plain-text editor rather than in whatever
/// handles `.toml`: many Macs have no `.toml` handler at all, and `NSWorkspace.open`
/// then does nothing. Only when there is no plain-text editor either does it fall back
/// to the file's own handler.
public struct WorkspaceConfigFileOpener: ConfigFileOpening {
    public init() {
        // Stateless: NSWorkspace.shared is the whole dependency.
    }

    /// Opens `path` in the default plain-text editor.
    ///
    /// The outcome is dropped, as ``WorkspaceSystemSettingsOpener`` drops its own: a
    /// user who sees no editor appear already knows what the app would learn, and no
    /// Core state would change on it.
    public func open(path: String) {
        let file = URL(fileURLWithPath: path)
        let workspace = NSWorkspace.shared
        guard let editor = workspace.urlForApplication(toOpen: .plainText) else {
            workspace.open(file)
            return
        }
        workspace.open(
            [file],
            withApplicationAt: editor,
            configuration: NSWorkspace.OpenConfiguration(),
        )
    }

    /// Opens a Finder window with `path` selected.
    public func reveal(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
