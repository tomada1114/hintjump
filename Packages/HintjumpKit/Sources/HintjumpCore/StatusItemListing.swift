import CoreGraphics
import Foundation

/// One on-screen window at the status-item level — normally one status item.
public struct StatusItemWindow: Equatable, Sendable {
    /// The process that owns the window. On recent macOS that can be a host process
    /// (Control Center) rather than the app the item belongs to, so it is data for a log
    /// line, never a decision.
    public let pid: pid_t
    /// The window's bounds in global, top-left-origin coordinates.
    public let frame: CGRect

    public init(pid: pid_t, frame: CGRect) {
        self.pid = pid
        self.frame = frame
    }
}

/// One look at the menu bar: where it is, which parts of it can show an item, and every
/// status-level window on screen. All frames are global, top-left-origin.
public struct StatusItemScan: Equatable, Sendable {
    /// The primary screen's menu bar.
    public let barFrame: CGRect
    /// The parts of ``barFrame`` an item can be seen in: the two sides of a camera
    /// housing, or the whole bar on a screen without one.
    public let visibleSegments: [CGRect]
    /// Every on-screen window at the status-item level, in the order the window server
    /// listed them. Which of them get a hint is ``StatusItemTargetCollector``'s decision.
    public let windows: [StatusItemWindow]

    public init(barFrame: CGRect, visibleSegments: [CGRect], windows: [StatusItemWindow]) {
        self.barFrame = barFrame
        self.visibleSegments = visibleSegments
        self.windows = windows
    }
}

/// A port: "which status items are in the menu bar right now?"
///
/// Status items are not in the frontmost app's accessibility tree — each belongs to its
/// own process — so this port asks the window server once for all of them rather than
/// asking Accessibility of every running process (`docs/decisions.md` › "Status items are
/// found in the on-screen window list"). Pull-style, like ``FrontmostAppProviding``, and
/// `@MainActor` because the screen geometry it reports is AppKit's, which is main-bound.
public protocol StatusItemListing: Sendable {
    /// The menu bar and the status-level windows on screen now, or `nil` when there is no
    /// screen.
    @MainActor
    func scan() -> StatusItemScan?
}
