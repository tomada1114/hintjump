import CoreGraphics
import HintjumpCore

/// The on-screen windows above the normal layer, from one `CGWindowListCopyWindowInfo`
/// call — shared by ``SystemTopmostContainerProbe``, which hands them to Core, and
/// ``AXUIElementTreeReader``'s ``HintjumpCore/ReadScope/popUpMenu`` root, which needs the
/// window to hit-test in.
///
/// Translation only: layer, bounds, and owner pid, none of which Screen Recording gates
/// (`kCGWindowName`, the one field that grant guards, is never read). Which window is a
/// panel, a menu, or noise is ``HintjumpCore/TopmostContainerRule``'s to say.
enum RaisedWindowList {
    /// `kCGNormalWindowLevel`: document windows. Everything listed is above it.
    static let normalLayer = Int(CGWindowLevelForKey(.normalWindow))
    /// `kCGPopUpMenuWindowLevel`: open menus, context menus, and some popovers.
    static let popUpMenuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))

    /// Every on-screen window above the normal layer, front to back — the order the window
    /// server lists them in.
    static func windows() -> [RaisedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else {
            return []
        }
        return entries.compactMap { entry -> RaisedWindow? in
            guard let layer = entry[kCGWindowLayer as String] as? Int,
                  layer > normalLayer,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  // Already global and top-left-origin: the window server's own space.
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else {
                return nil
            }
            return RaisedWindow(
                pid: pid,
                layer: layer,
                frame: frame,
                isPopUpMenuLevel: layer == popUpMenuLayer,
            )
        }
    }
}
