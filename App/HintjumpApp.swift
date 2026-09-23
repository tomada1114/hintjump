import AppKit
import HintjumpCore
import HintjumpPlatform
import HintjumpUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/HintjumpKit.
///
/// A menu-bar agent: `LSUIElement` (`project.yml`) keeps it out of the Dock and the app
/// switcher, so the `MenuBarExtra` is the way in. `.menuBarExtraStyle(.menu)` renders the
/// content as an `NSMenu`, which is the shape the status menu has (a list of items) and
/// the one XCUITest can reach by title (`app.menuItems[...]`). The `Settings` scene is
/// the Settings window "Settings…" opens (`docs/architecture.md` › The Settings window).
///
/// `App/` is the composition root — the one place that knows both halves of a port — and
/// ``AppComposition`` holds most of it, so this struct stays scenes and wiring
/// (`docs/architecture.md` › Layers).
@main
struct HintjumpApp: App {
    /// The config store, the triggers, the Accessibility gate, the status menu's model,
    /// and the Settings window's, composed once — it must survive scene recreation — and
    /// started from the label's `.onAppear` below.
    @State private var composition = AppComposition()

    var body: some Scene {
        MenuBarExtra {
            // "Disable in <App>" / "Enable in <App>" for the last app frontmost other than
            // Hintjump; absent, with its divider, until there is one with a bundle
            // identifier (`docs/design/settings-window.md` › Status menu).
            if let title = composition.statusMenu.disableItemTitle {
                Button(title) {
                    composition.statusMenu.toggleDisabledForLastApp()
                }
                Divider()
            }
            SettingsMenuItem()
            Button("Open Config File") {
                composition.statusMenu.openConfigFile()
            }
            // Re-reads the config file and applies it: `launch_at_login`, then the
            // triggers. A failure is logged and the triggers stay as they were. Removed
            // once #102 watches the file.
            Button("Reload Config") {
                composition.statusMenu.reloadConfig()
            }
            Divider()
            // An agent has no app menu and no ⌘Q of its own, so this is how it quits.
            Button("Quit Hintjump") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            // The label is the one view a menu-bar agent renders at launch — the
            // `.menu` content is built only when the menu opens — so the gate that
            // has to run at launch and on activation is attached here, and so is the
            // start that loads the config (applying `launch_at_login`) and registers
            // the triggers.
            // The hint-tag template image with the pointer arrow inside, drawn by
            // `StatusIcon` in HintjumpUI. The update dot and config-error "!" states are
            // drawn there too, for the features that will report them.
            StatusIcon.image(for: .normal)
                .accessibilityGate(composition.accessibilityGate)
                .onAppear {
                    composition.start()
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: composition.settings)
        }
    }
}
