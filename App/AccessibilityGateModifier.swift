import HintjumpCore
import SwiftUI

/// Drives ``AccessibilityGateViewModel`` from scene-phase changes.
///
/// Lives in `App/`, the composition root, so it stays independent of the scene type:
/// today `HintjumpApp` wraps a `WindowGroup`'s `ContentView`, and issue #11 will make it
/// a `MenuBarExtra` later — this modifier attaches to whichever root view the scene
/// hands it either way. It holds no logic of its own beyond "when": every decision about
/// what `refresh()` and `promptIfNeeded()` do lives in the view model, in `HintjumpCore`.
private struct AccessibilityGateModifier: ViewModifier {
    let gate: AccessibilityGateViewModel
    @Environment(\.scenePhase)
    private var scenePhase

    func body(content: Content) -> some View {
        content
            // `initial: true` covers the case where the scene is already active on
            // first render, matching `ContentView`'s frontmost-app refresh. Refreshing
            // is how the app notices a grant given in System Settings, since macOS
            // reports one through no callback at all.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else {
                    return
                }
                gate.refresh()
                // Spent at most once per process, and only while blocked: see
                // `AccessibilityGateViewModel.promptIfNeeded()`.
                gate.promptIfNeeded()
            }
    }
}

extension View {
    /// Wires `self` to refresh and, when needed, prompt for the Accessibility grant at
    /// launch and whenever the app becomes active.
    func accessibilityGate(_ gate: AccessibilityGateViewModel) -> some View {
        modifier(AccessibilityGateModifier(gate: gate))
    }
}
