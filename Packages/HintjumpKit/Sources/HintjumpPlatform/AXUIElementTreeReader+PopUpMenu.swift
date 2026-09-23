import ApplicationServices
import HintjumpCore

/// Finding the root of a ``HintjumpCore/ReadScope/popUpMenu`` read: the menu open in a
/// process's frontmost pop-up-menu-level window.
///
/// A context menu is reachable no other way (`docs/research/topmost-container.md`): it is
/// not a child of the application, nothing on the menu bar is selected, the element that
/// was right-clicked does not list it, and `AXFocusedWindow` is empty while it is open.
/// Its window is on screen at `kCGPopUpMenuWindowLevel`, though, and asking the
/// system-wide element what lies inside that window answers a menu item whose ancestors
/// include the menu. Read-only: a hit test asks the Accessibility API about a point; it
/// moves no pointer and posts no event. The geometry — the window the server lists first,
/// 20 pt below its top edge — is the one the probe's `popup` lines verified.
extension AXUIElementTreeReader {
    /// How far below a menu window's top edge the hit test asks, in points: past the
    /// menu's top padding, onto its first item, and never below the window's middle.
    static let popUpMenuHitInset: CGFloat = 20
    /// How many elements the walk up from the hit element visits before it gives up. A
    /// context menu in a Finder list sits eight levels below the application.
    static let popUpMenuAncestorLimit = 12

    /// The `AXMenu` nearest above the element 20 pt inside the frontmost
    /// pop-up-menu-level window `pid` owns, when that menu is `pid`'s.
    ///
    /// Throws ``HintjumpCore/AccessibilityReadError/attributeUnsupported(_:)`` naming
    /// `AXMenu` when `pid` owns no such window, when the hit test answers nothing, when no
    /// menu is found above the hit — a menu fading out lets the hit fall through to the
    /// window beneath, and a popover drawn at that level has no menu at all — and when the
    /// menu belongs to another process.
    static func popUpMenu(of pid: pid_t) throws -> AXUIElement {
        let missing = AccessibilityReadError.attributeUnsupported(kAXMenuRole as String)
        guard let window = RaisedWindowList.windows()
            .first(where: { $0.isPopUpMenuLevel && $0.pid == pid })
        else {
            throw missing
        }
        let bounds = window.frame
        let point = CGPoint(
            x: bounds.midX,
            y: bounds.minY + min(popUpMenuHitInset, bounds.midY - bounds.minY),
        )
        var hit: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(point.x),
            Float(point.y),
            &hit,
        )
        if error == .apiDisabled {
            throw AccessibilityReadError.notTrusted
        }
        guard error == .success, let hit, let menu = nearestMenu(from: hit, pid: pid),
              processIdentifier(of: menu) == pid
        else {
            throw missing
        }
        return menu
    }

    /// `start`, or the nearest of its ancestors whose role is `AXMenu`, within
    /// ``popUpMenuAncestorLimit`` elements.
    private static func nearestMenu(from start: AXUIElement, pid: pid_t) -> AXUIElement? {
        var current: AXUIElement? = start
        for _ in 0 ..< popUpMenuAncestorLimit {
            guard let element = current else {
                return nil
            }
            let role = individualValues(of: element, names: [kAXRoleAttribute as String])
            if role[kAXRoleAttribute as String] as? String == kAXMenuRole as String {
                return element
            }
            current = try? self.element(kAXParentAttribute as String, of: element, pid: pid)
        }
        return nil
    }

    private static func processIdentifier(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }
        return pid
    }
}
