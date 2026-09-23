import AppKit
import HintjumpCore
import SwiftUI

/// "Settings…" ⌘, in the status menu: brings Hintjump to the front, then opens the
/// Settings window.
///
/// A view of its own because `openSettings` is read from the environment. The
/// activation comes first because an `LSUIElement` agent is never the active app while
/// another app is in front, so a window it opens would otherwise appear behind that app.
/// ⌘, works while the menu is open, as every menu item's key equivalent does.
struct SettingsMenuItem: View {
    @Environment(\.openSettings)
    private var openSettings

    var body: some View {
        Button("Settings…") {
            AppLog.settings.info("settings window requested from the status menu")
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",")
    }
}
