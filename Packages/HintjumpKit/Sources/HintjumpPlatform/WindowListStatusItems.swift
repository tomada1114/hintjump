import AppKit
import HintjumpCore

/// The window-server-backed adapter for ``HintjumpCore/StatusItemListing``: one
/// `CGWindowListCopyWindowInfo` call for every process's status items, and the primary
/// screen's geometry for where the menu bar is.
///
/// Translation only. It reads a window's layer, bounds, and owner pid — none of which
/// Screen Recording gates; `kCGWindowName`, the one field that grant guards, is never
/// read — and keeps the windows at the status-item level. Which of them get a hint —
/// inside the bar, clear of a camera housing, not a sliver, not a duplicate — is
/// ``HintjumpCore/StatusItemTargetCollector``'s decision.
///
/// Stateless and retains no OS object, so nothing here can cross an isolation boundary.
public struct WindowListStatusItems: StatusItemListing {
    public init() {
        // Stateless: every scan asks the window server and the screen afresh.
    }

    /// The primary screen's menu bar, top-left-origin: the strip above the screen's
    /// visible frame, or the status bar's thickness when the menu bar is auto-hidden and
    /// that strip is empty.
    @MainActor
    private static func barFrame(of screen: NSScreen) -> CGRect {
        let strip = screen.frame.maxY - screen.visibleFrame.maxY
        let height = strip > 0 ? strip : NSStatusBar.system.thickness
        return CGRect(x: screen.frame.minX, y: 0, width: screen.frame.width, height: height)
    }

    /// The bar beside a camera housing — the horizontal extents of the screen's two
    /// auxiliary top areas at the bar's height — or the whole bar on a screen without one.
    @MainActor
    private static func visibleSegments(of screen: NSScreen, bar: CGRect) -> [CGRect] {
        let sides = [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea].compactMap { area in
            area.map { CGRect(x: $0.minX, y: bar.minY, width: $0.width, height: bar.height) }
        }
        return sides.isEmpty ? [bar] : sides
    }

    /// Every on-screen window at the status-item level, as the window server lists them.
    private static func statusLevelWindows() -> [StatusItemWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let entries = CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID,
        ) as? [[String: Any]] else {
            return []
        }
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        return entries.compactMap { entry -> StatusItemWindow? in
            guard entry[kCGWindowLayer as String] as? Int == statusLevel,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  // Already global and top-left-origin: the window server's own space.
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else {
                return nil
            }
            return StatusItemWindow(pid: pid, frame: frame)
        }
    }

    /// The primary screen's menu bar and the status-level windows on screen, or `nil`
    /// with no screen.
    @MainActor
    public func scan() -> StatusItemScan? {
        guard let screen = NSScreen.screens.first else {
            return nil
        }
        let bar = Self.barFrame(of: screen)
        return StatusItemScan(
            barFrame: bar,
            visibleSegments: Self.visibleSegments(of: screen, bar: bar),
            windows: Self.statusLevelWindows(),
        )
    }
}
