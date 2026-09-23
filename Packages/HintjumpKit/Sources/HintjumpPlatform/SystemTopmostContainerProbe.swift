import AppKit
import ApplicationServices
import HintjumpCore

/// The system-backed adapter for ``HintjumpCore/TopmostContainerProbing``: the system-wide
/// `AXFocusedApplication`, the on-screen windows above the normal layer, and the primary
/// screen's menu bar strip.
///
/// Translation only, and no tree is walked: one Accessibility call to the system-wide
/// element, one `CGWindowListCopyWindowInfo` call (``RaisedWindowList``), and the screen
/// geometry `WindowListStatusItems` already reads. Which window is a panel, a context
/// menu, or noise is ``HintjumpCore/TopmostContainerRule``'s decision.
///
/// Stateless and retains no OS object, so nothing here can cross an isolation boundary.
public struct SystemTopmostContainerProbe: TopmostContainerProbing {
    public init() {
        // Stateless: every press asks the Accessibility API and the window server afresh.
    }

    /// The pid of the system-wide `AXFocusedApplication`, or `nil` for any failure.
    ///
    /// `nil` rather than an error: #9's runs saw `kAXErrorCannotComplete` on an Electron
    /// app's first read, and the port reads a missing answer as "no other panel", so the
    /// trigger falls back to the frontmost application's focused window. Without the
    /// Accessibility grant this is `nil` too, and the tree read that follows reports the
    /// missing grant as itself.
    @MainActor
    private static func focusedApplicationPID() -> pid_t? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedApplicationAttribute as CFString,
            &value,
        )
        // `unsafeDowncast` behind a `CFGetTypeID` guard, as in `AXUIElementTreeReader`: a
        // conditional cast to a Core Foundation type is rejected as one that cannot fail.
        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        var pid: pid_t = 0
        guard AXUIElementGetPid(unsafeDowncast(value, to: AXUIElement.self), &pid) == .success
        else {
            return nil
        }
        return pid
    }

    /// The signals now. With no screen the menu bar strip is the status bar's thickness,
    /// the same reading `WindowListStatusItems` makes of an auto-hidden bar.
    @MainActor
    public func signals() -> TopmostContainerSignals {
        let barHeight = NSScreen.screens.first.map { WindowListStatusItems.barFrame(of: $0).height }
        return TopmostContainerSignals(
            focusedApplicationPID: Self.focusedApplicationPID(),
            menuBarHeight: barHeight ?? NSStatusBar.system.thickness,
            raisedWindows: RaisedWindowList.windows(),
        )
    }
}
