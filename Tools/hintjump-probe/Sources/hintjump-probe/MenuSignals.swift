import ApplicationServices

/// A menu the Accessibility API shows open, and where it was reached from.
struct OpenMenu {
    /// `application` for a menu that is a direct child of the application element (a
    /// context menu), or `menuBar:"File"` / `extrasMenuBar:"…"` for one under a selected
    /// title of that bar.
    let via: String
    /// The pid the menu element itself answers with — not assumed to be the reader's.
    let pid: pid_t?
    let frame: CGRect?
    /// `AXChildren` of the menu: its items and separators, before any clickable filter.
    let childCount: Int
}

/// A menu bar title or status item that reports `AXSelected`, which is how a bar says
/// that what it opened is showing — a menu, or a panel that is no menu at all.
struct BarSelection {
    /// `menuBar` (`AXMenuBar`) or `extrasMenuBar` (`AXExtrasMenuBar`, an application's
    /// status items).
    let bar: String
    let title: String?
    let label: String?
}

/// Every open menu and selected bar item one application's accessibility tree shows.
struct MenuSignals {
    /// The two bars an application can publish, by attribute and by the name printed.
    private static let bars = [
        (attribute: kAXMenuBarAttribute, name: "menuBar"),
        (attribute: "AXExtrasMenuBar", name: "extrasMenuBar"),
    ]

    let openMenus: [OpenMenu]
    let selections: [BarSelection]

    /// Reads `application`'s direct `AXMenu` children and each bar's selected items,
    /// and the `AXMenu` under each selected item.
    ///
    /// Only a selected title's menu is read: every title of a bar has an `AXMenu` child
    /// whether or not it is open (a closed one reports a zero-size frame — Finder's are
    /// `0,1440,0,0`), so reading them all would cost a dozen calls and say nothing. The
    /// frame is printed rather than filtered on, so a stale selection shows as one.
    static func read(from application: AXUIElement) -> Self {
        var menus = AXRaw.elements(kAXChildrenAttribute, of: application)
            .filter { AXRaw.string(kAXRoleAttribute, of: $0) == kAXMenuRole }
            .map { openMenu($0, via: "application") }
        var selected: [BarSelection] = []
        for bar in bars {
            guard let barElement = AXRaw.element(bar.attribute, of: application) else {
                continue
            }
            for item in AXRaw.elements(kAXChildrenAttribute, of: barElement) {
                guard AXRaw.isTrue(kAXSelectedAttribute, of: item) else {
                    continue
                }
                let title = AXRaw.string(kAXTitleAttribute, of: item)
                selected.append(BarSelection(
                    bar: bar.name,
                    title: title,
                    label: AXRaw.string(kAXDescriptionAttribute, of: item),
                ))
                let via = "\(bar.name):\(quoted(title))"
                menus += AXRaw.elements(kAXChildrenAttribute, of: item)
                    .filter { AXRaw.string(kAXRoleAttribute, of: $0) == kAXMenuRole }
                    .map { openMenu($0, via: via) }
            }
        }
        return Self(openMenus: menus, selections: selected)
    }

    private static func openMenu(_ menu: AXUIElement, via: String) -> OpenMenu {
        OpenMenu(
            via: via,
            pid: AXRaw.processIdentifier(of: menu),
            frame: AXRaw.frame(of: menu),
            childCount: AXRaw.elements(kAXChildrenAttribute, of: menu).count,
        )
    }
}
