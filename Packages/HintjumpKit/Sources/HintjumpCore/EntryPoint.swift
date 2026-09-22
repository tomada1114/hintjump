/// One of the four ways into a hint session, each with its own global shortcut
/// (`docs/decisions.md` › "Four entry points, each its own shortcut, never more").
///
/// The raw value is the `[triggers]` key the shortcut is written under, so a log line
/// names the trigger the way the user's file does, and every later entry-point feature
/// switches over this one enum rather than over strings.
public enum EntryPoint: String, CaseIterable, Sendable {
    /// The menu bar's app menus.
    case appMenus = "app_menus"
    /// Left click in the frontmost window.
    case clickInWindow = "click_in_window"
    /// Right click in the frontmost window.
    case rightClickInWindow = "right_click_in_window"
    /// The menu bar's status items.
    case statusIcons = "status_icons"

    /// The four in file order — the order the `[triggers]` section writes them and the
    /// order they are registered in — rather than the declaration order, which
    /// SwiftLint's `sorted_enum_cases` keeps alphabetical.
    public static let allCases: [Self] = [
        .clickInWindow,
        .rightClickInWindow,
        .appMenus,
        .statusIcons,
    ]
}
