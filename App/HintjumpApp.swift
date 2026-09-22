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
/// This is also the composition root: the one place that knows both halves of a port.
/// It constructs the `HintjumpPlatform` adapters and hands them to `HintjumpCore` view
/// models, so nothing below `App/` — not the view model, not the view — depends on which
/// implementation answers (`docs/architecture.md` › Layers).
@main
struct HintjumpApp: App {
    /// The temporary status-item image, until the real template image lands.
    static let statusItemImage = "rectangle.dashed"

    /// Composed once, here, rather than inside the view: it must survive scene
    /// recreation and keep its own `hasPrompted` state for the life of the process.
    @State private var accessibilityGate =
        AccessibilityGateViewModel(trust: SystemAccessibilityTrust())

    /// Composed once, for the same reason, and loaded before the first scene exists:
    /// the load at launch is what applies `launch_at_login` without a Reload.
    @State private var configStore = Self.loadedConfigStore()

    var body: some Scene {
        MenuBarExtra {
            // Re-reads the config file and applies it, `launch_at_login` included.
            // A failure is logged and recorded by the store, as at launch.
            Button("Reload Config") {
                _ = try? configStore.reload()
            }
            Divider()
            // An agent has no app menu and no ⌘Q of its own, so this is how a local run
            // quits. The other items (Open Config File, Disable in <App>, Status…) come
            // with the status-menu feature.
            Button("Quit Hintjump") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            // The label is the one view a menu-bar agent renders at launch — the
            // `.menu` content is built only when the menu opens — so the gate that
            // has to run at launch and on activation is attached here.
            Image(systemName: Self.statusItemImage)
                .accessibilityGate(accessibilityGate)
        }
        .menuBarExtraStyle(.menu)
    }

    /// The config store over the real file and the real login item, loaded once.
    ///
    /// `load()` logs a failure itself and records it in `lastLoad`, and a failed load
    /// leaves the default configuration in force, so launch carries on either way.
    private static func loadedConfigStore() -> ConfigStore {
        let store = ConfigStore(file: UserConfigFile(), loginItem: SMAppServiceLoginItem())
        _ = try? store.load()
        return store
    }
}
