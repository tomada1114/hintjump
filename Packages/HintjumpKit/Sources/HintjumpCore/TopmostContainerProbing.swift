import CoreGraphics
import Foundation

/// One on-screen window above the normal window layer, as the window server lists it.
///
/// Layer, bounds, and owner pid are the fields of the window list that need no grant
/// (Screen Recording gates only a window's name), and they are all
/// ``TopmostContainerRule`` asks of a window.
public struct RaisedWindow: Equatable, Sendable {
    /// The process that owns the window.
    public let pid: pid_t
    /// The window's layer, carried for the log; ``isPopUpMenuLevel`` is what the rule
    /// reads, so that Core never needs the window server's level constants.
    public let layer: Int
    /// The window's bounds in global, top-left-origin coordinates.
    public let frame: CGRect
    /// Whether the window is at `kCGPopUpMenuWindowLevel` — open menus, context menus, and
    /// some popovers.
    public let isPopUpMenuLevel: Bool

    public init(pid: pid_t, layer: Int, frame: CGRect, isPopUpMenuLevel: Bool) {
        self.pid = pid
        self.layer = layer
        self.frame = frame
        self.isPopUpMenuLevel = isPopUpMenuLevel
    }
}

/// Exactly what ``TopmostContainerRule`` reads before a frontmost-window trigger reads a
/// tree: who has keyboard focus system-wide, and which windows sit above the normal layer.
///
/// None of it names an `AXUIElement`, and none of it is a decision: which of these windows
/// is a panel, a menu, or noise is the rule's to say (`docs/research/topmost-container.md`).
public struct TopmostContainerSignals: Equatable, Sendable {
    /// The pid of the system-wide `AXFocusedApplication`, or `nil` when it could not be
    /// read — `kAXErrorCannotComplete` on an Electron app's first read, or no grant. It
    /// differs from the frontmost application while another process's panel (Control
    /// Center, Notification Center, Spotlight) has taken focus without activating.
    public let focusedApplicationPID: pid_t?
    /// The height of the primary screen's menu bar strip, measured from the screen's top
    /// edge (y = 0): a window wholly inside it is a status item or the bar, not a panel.
    public let menuBarHeight: CGFloat
    /// Every on-screen window above the normal layer, front to back — the window server's
    /// order, so the first pop-up-menu-level window listed is the frontmost one.
    public let raisedWindows: [RaisedWindow]

    public init(
        focusedApplicationPID: pid_t?,
        menuBarHeight: CGFloat,
        raisedWindows: [RaisedWindow],
    ) {
        self.focusedApplicationPID = focusedApplicationPID
        self.menuBarHeight = menuBarHeight
        self.raisedWindows = raisedWindows
    }
}

/// A port: "what is on top of the frontmost window right now?"
///
/// No single Accessibility attribute answers that — #9's runs found a different signal for
/// each kind of container — so this port hands Core the raw signals, and
/// ``TopmostContainerRule`` decides. Its adapter reads them without walking any tree: one
/// system-wide attribute and one window-list call per trigger press. Pull-style, like
/// ``FrontmostAppProviding``, and `@MainActor` because the Accessibility API and the
/// screen geometry it reads are main-bound.
public protocol TopmostContainerProbing: Sendable {
    /// The signals now.
    @MainActor
    func signals() -> TopmostContainerSignals
}
