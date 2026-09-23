import AppKit

/// One on-screen window above the normal layer, as the window server lists it.
///
/// This is how a panel another process draws is found at all: Control Center's Wi-Fi
/// panel, Notification Center, and Spotlight are not in the frontmost application's
/// accessibility tree, but they are windows, and the window server says who owns each.
/// Layer, bounds, owner pid, and owner name need no Screen Recording grant; the window's
/// own name, which does, is never read.
struct WindowServerWindow {
    /// `kCGNormalWindowLevel`: document windows. Everything listed is above it.
    static let normalLayer = Int(CGWindowLevelForKey(.normalWindow))

    let layer: Int
    let pid: pid_t
    let ownerName: String?
    let bounds: CGRect
    /// Whether the window lies wholly inside the primary screen's menu bar strip — the
    /// bar itself and every status item. Printed, so the parent can tell a status item
    /// from the panel it opened, and used to skip reading the dozens of processes that
    /// own a status item and nothing else.
    let isInMenuBarStrip: Bool

    /// The owner's bundle identifier, or `nil` for a process that is not an
    /// application (the window server itself owns the menu bar).
    @MainActor var bundleIdentifier: String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    /// `owner:layer`, the unit a watch signature counts.
    var signatureKey: String {
        "\(ownerName ?? "pid\(pid)"):\(layer)"
    }

    /// Every on-screen window above the normal layer, front to back.
    @MainActor
    static func aboveNormalLayer() -> [Self] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else {
            return []
        }
        let strip = menuBarHeight()
        return entries.compactMap { entry -> Self? in
            guard let entryLayer = entry[kCGWindowLayer as String] as? Int,
                  entryLayer > normalLayer,
                  let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsEntry = entry[kCGWindowBounds as String] as? [String: Any],
                  // Already global and top-left-origin: the window server's own space.
                  let frame = CGRect(dictionaryRepresentation: boundsEntry as CFDictionary)
            else {
                return nil
            }
            return Self(
                layer: entryLayer,
                pid: ownerPID,
                ownerName: entry[kCGWindowOwnerName as String] as? String,
                bounds: frame,
                isInMenuBarStrip: frame.maxY <= strip,
            )
        }
    }

    /// The primary screen's menu bar height: the strip above its visible frame, or the
    /// status bar's thickness when the bar is auto-hidden and that strip is empty — the
    /// same reading `WindowListStatusItems` makes.
    @MainActor
    private static func menuBarHeight() -> CGFloat {
        guard let screen = NSScreen.screens.first else {
            return NSStatusBar.system.thickness
        }
        let strip = screen.frame.maxY - screen.visibleFrame.maxY
        return strip > 0 ? strip : NSStatusBar.system.thickness
    }
}
