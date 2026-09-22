import HintjumpCore
import HintjumpPlatform
import HintjumpUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/HintjumpKit.
///
/// This is also the composition root: the one place that knows both halves of a port.
/// It constructs the `HintjumpPlatform` adapters and hands them to `HintjumpCore` view
/// models, so nothing below `App/` — not the view model, not the view — depends on which
/// implementation answers (`docs/architecture.md` › Layers).
@main
struct HintjumpApp: App {
    /// Composed once, here, rather than inside the view: it must survive scene
    /// recreation and keep its own `hasPrompted` state for the life of the process.
    @State private var accessibilityGate =
        AccessibilityGateViewModel(trust: SystemAccessibilityTrust())

    var body: some Scene {
        WindowGroup {
            ContentView(
                frontmostApp: FrontmostAppViewModel(provider: WorkspaceFrontmostAppProvider()),
            )
            .accessibilityGate(accessibilityGate)
        }
    }
}
