import AppKit

/// A pop-up-menu-level window the frontmost application owns, and the menu that
/// hit-testing inside it finds.
///
/// This is the only signal a context menu gives (#9's research,
/// `docs/research/topmost-container.md`). The menu is not a child of the application
/// element, nothing on the menu bar is selected, and the element that was right-clicked
/// does not list it in `AXChildren` — but its window is on screen at
/// `kCGPopUpMenuWindowLevel`, and asking the system-wide element what lies inside that
/// window answers a menu item whose ancestors include the menu. Read-only: a hit test
/// asks the Accessibility API about a point; it moves no pointer and posts no event.
struct PopupMenu {
    /// `kCGPopUpMenuWindowLevel`: open menus, context menus, and some popovers.
    static let popUpMenuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
    /// How far below a menu window's top edge the hit test asks, in points: past the
    /// menu's top padding, onto its first item, and never below the window's middle.
    static let hitInset: CGFloat = 20
    /// How many ancestors the walk up from the hit element follows before it gives up.
    /// A context menu in a Finder list sits eight levels below the application.
    static let maximumAncestors = 12

    let window: WindowServerWindow
    /// The pid of the element the hit test answered, or `nil` for no answer.
    let hitPid: pid_t?
    /// Roles from the hit element upward, ending at the first `AXMenu` when there is one.
    let chain: [String]
    /// The nearest `AXMenu` above the hit element, or `nil` — a menu fading out lets
    /// the hit fall through to the window beneath, and a popover has no menu at all.
    let menu: AXUIElement?
    /// The role of the menu's `AXParent`: `AXOutline` or another view for a context
    /// menu, `AXMenuBarItem` for a menu-bar menu, `AXMenuItem` for a submenu.
    let menuParentRole: String?

    /// `AXMenu<AXOutline@793`, or `none<AXRow` when no menu was found.
    var signatureKey: String {
        let pid = hitPid.map(String.init) ?? "-"
        guard menu != nil else {
            return "none<\(chain.first ?? "-")@\(pid)"
        }
        return "AXMenu<\(menuParentRole ?? "-")@\(pid)"
    }

    /// Hit-tests every on-screen pop-up-menu-level window `pid` owns, front to back.
    @MainActor
    static func read(from windows: [WindowServerWindow], pid: pid_t) -> [Self] {
        let systemWide = AXUIElementCreateSystemWide()
        return windows
            .filter { $0.layer == popUpMenuLayer && $0.pid == pid }
            .map { hitTest($0, systemWide: systemWide) }
    }

    private static func hitTest(_ window: WindowServerWindow, systemWide: AXUIElement) -> Self {
        let bounds = window.bounds
        let point = CGPoint(
            x: bounds.midX,
            y: bounds.minY + min(hitInset, bounds.midY - bounds.minY),
        )
        var hit: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(point.y),
            &hit,
        )
        guard error == .success, let hit else {
            return Self(window: window, hitPid: nil, chain: [], menu: nil, menuParentRole: nil)
        }
        var roles: [String] = []
        var current: AXUIElement? = hit
        for _ in 0 ..< maximumAncestors {
            guard let element = current else {
                break
            }
            let role = AXRaw.string(kAXRoleAttribute, of: element) ?? "-"
            roles.append(role)
            if role == kAXMenuRole {
                let parent = AXRaw.element(kAXParentAttribute, of: element)
                return Self(
                    window: window,
                    hitPid: AXRaw.processIdentifier(of: hit),
                    chain: roles,
                    menu: element,
                    menuParentRole: parent.flatMap { AXRaw.string(kAXRoleAttribute, of: $0) },
                )
            }
            current = AXRaw.element(kAXParentAttribute, of: element)
        }
        return Self(
            window: window,
            hitPid: AXRaw.processIdentifier(of: hit),
            chain: roles,
            menu: nil,
            menuParentRole: nil,
        )
    }
}
