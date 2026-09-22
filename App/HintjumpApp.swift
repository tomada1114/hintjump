import AppKit
import HintjumpCore
import HintjumpPlatform
import HintjumpUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/HintjumpKit.
///
/// A menu-bar agent: `LSUIElement` (`project.yml`) keeps it out of the Dock and the app
/// switcher, so the `MenuBarExtra` is the whole user interface. `.menuBarExtraStyle(.menu)`
/// renders the content as an `NSMenu`, which is the shape the status menu has (a list of
/// items) and the one XCUITest can reach by title (`app.menuItems[...]`).
///
/// `App/` is the composition root — the one place that knows both halves of a port — and
/// ``AppComposition`` holds most of it, so this struct stays scenes and wiring
/// (`docs/architecture.md` › Layers).
@main
struct HintjumpApp: App {
    /// The temporary status-item image, until the real template image lands.
    static let statusItemImage = "rectangle.dashed"

    /// Composed once, here, rather than inside the view: it must survive scene
    /// recreation and keep its own `hasPrompted` state for the life of the process.
    @State private var accessibilityGate =
        AccessibilityGateViewModel(trust: SystemAccessibilityTrust())

    /// The config store, the triggers, and the status menu's model, composed once for
    /// the same reason and started from the label's `.onAppear` below.
    @State private var composition = AppComposition()

    var body: some Scene {
        MenuBarExtra {
            Button("Open Config File") {
                composition.statusMenu.openConfigFile()
            }
            // Re-reads the config file and applies it: `launch_at_login`, then the
            // triggers. A failure is logged and the triggers stay as they were.
            Button("Reload Config") {
                composition.statusMenu.reloadConfig()
            }
            Divider()
            // An agent has no app menu and no ⌘Q of its own, so this is how a local run
            // quits. The other items (Disable in <App>, Status…) come with later
            // status-menu features.
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
            Image(systemName: Self.statusItemImage)
                .accessibilityGate(accessibilityGate)
                .onAppear {
                    composition.start()
                }
        }
        .menuBarExtraStyle(.menu)
    }
}
