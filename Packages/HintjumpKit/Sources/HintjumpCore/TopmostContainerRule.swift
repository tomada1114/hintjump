import CoreGraphics
import Foundation

/// What a frontmost-window trigger ended up labeling — one case per check of
/// ``TopmostContainerRule``, and the name the session's `shown` log line reports.
public enum TopmostContainer: String, CaseIterable, Sendable {
    /// Check 2: the menu open in the frontmost app's pop-up-menu-level window — a context
    /// menu, or the submenu open on one.
    case contextMenu
    /// Check 5: the focused window itself, whatever its subrole.
    case focusedWindow
    /// Check 1: a panel another process drew and gave focus to — Control Center's,
    /// Notification Center, Spotlight, a third-party launcher.
    case otherProcessPanel
    /// Check 4: a popover inside the focused window.
    case popover
    /// Check 3: the focused window is a sheet — a save panel or a save-changes alert.
    case sheet

    /// Where the read that finds this container starts. Everything but a context menu is
    /// some process's focused window: a sheet is `AXFocusedWindow` already, and a popover
    /// sits inside it.
    public var scope: ReadScope {
        switch self {
        case .contextMenu:
            .popUpMenu

        case .focusedWindow, .otherProcessPanel, .popover, .sheet:
            .focusedWindow
        }
    }
}

/// The read ``TopmostContainerRule/resolve(_:frontmostPID:ownPID:)`` picks: which process,
/// from which root, and which container it expects to find there.
public struct TopmostRead: Equatable, Sendable {
    /// The process to read — another one's for ``TopmostContainer/otherProcessPanel``.
    public let pid: pid_t
    /// Where the read starts.
    public let scope: ReadScope
    /// What the read is of. ``TopmostContainer/focusedWindow`` is refined after the read
    /// by ``TopmostContainerRule/container(in:)``, which is where a sheet or a popover is
    /// told apart.
    public let container: TopmostContainer

    public init(pid: pid_t, scope: ReadScope, container: TopmostContainer) {
        self.pid = pid
        self.scope = scope
        self.container = container
    }
}

/// "Whatever is on top", decided: the ordered targeting rule of `docs/decisions.md` ›
/// "What 'whatever is on top' means: an ordered targeting rule; open menu-bar menus are
/// out of scope", implemented verbatim from `docs/research/topmost-container.md` › "The
/// targeting rule". The first check that matches wins:
///
/// 1. The system-wide focused application is neither the frontmost app nor Hintjump,
///    and owns an on-screen window above the normal layer that is not wholly inside the
///    menu bar strip and is taller than 40 pt: that process's focused window.
/// 2. The frontmost app owns an on-screen pop-up-menu-level window: the menu a hit test
///    inside the frontmost such window finds, if it belongs to the frontmost app. The hit
///    test is the read's (``ReadScope/popUpMenu``); when it finds no menu the collector
///    goes on to the checks below.
/// 3. The focused window is an `AXSheet`: the sheet.
/// 4. The focused window's subtree holds an `AXPopover`: the popover.
/// 5. Otherwise the focused window — and with none, nothing.
///
/// Checks 1 and 2 are answered from ``TopmostContainerSignals`` before any tree is read
/// (``resolve(_:frontmostPID:ownPID:)``); checks 3 to 5 need no signal of their own,
/// because a `.focusedWindow` read already holds the sheet or the popover, so they are
/// answered from that read (``container(in:)``). A floating panel is never focused and an
/// open menu-bar menu never receives the trigger, so both fall through to the focused
/// window, as the decision says.
public enum TopmostContainerRule {
    /// Another process's window this short or shorter is not a panel.
    static let minimumPanelHeight: CGFloat = 40
    static let sheetRole = "AXSheet"
    static let popoverRole = "AXPopover"

    /// Checks 1 and 2 over `signals`; ``TopmostContainer/focusedWindow`` of `frontmostPID`
    /// when neither matches.
    ///
    /// `ownPID` is Hintjump's: its overlay is a full-screen pop-up-menu-level window and
    /// takes system focus while it is shown, so it would otherwise pass check 1.
    public static func resolve(
        _ signals: TopmostContainerSignals,
        frontmostPID: pid_t,
        ownPID: pid_t,
    ) -> TopmostRead {
        if let panelOwner = panelOwner(in: signals, frontmostPID: frontmostPID, ownPID: ownPID) {
            return TopmostRead(
                pid: panelOwner,
                scope: .focusedWindow,
                container: .otherProcessPanel,
            )
        }
        let ownsPopUpMenuWindow = signals.raisedWindows.contains { window in
            window.isPopUpMenuLevel && window.pid == frontmostPID
        }
        if ownsPopUpMenuWindow {
            return TopmostRead(pid: frontmostPID, scope: .popUpMenu, container: .contextMenu)
        }
        return TopmostRead(pid: frontmostPID, scope: .focusedWindow, container: .focusedWindow)
    }

    /// Checks 3 to 5 over a `.focusedWindow` read, `elements` in the read's pre-order: the
    /// container found, and the elements to rank — the read itself for a sheet or a plain
    /// window, or the first popover's subtree re-rooted at the popover.
    ///
    /// Only a popover with a non-empty frame counts: one without is not on screen, and a
    /// frameless root would leave nothing to rank. Only one open popover was ever seen at a
    /// time, so the first in tree order is taken.
    public static func container(
        in elements: [ElementSnapshot],
    ) -> (container: TopmostContainer, elements: [ElementSnapshot]) {
        guard let root = elements.first else {
            return (.focusedWindow, elements)
        }
        if root.role == sheetRole {
            return (.sheet, elements)
        }
        let popover = elements.indices.dropFirst().first { index in
            elements[index].role == popoverRole && !(elements[index].frame?.isEmpty ?? true)
        }
        guard let popover else {
            return (.focusedWindow, elements)
        }
        return (.popover, subtree(at: popover, in: elements))
    }

    /// Check 1: the focused application, when it is another process than the frontmost
    /// app and this one and owns a panel.
    private static func panelOwner(
        in signals: TopmostContainerSignals,
        frontmostPID: pid_t,
        ownPID: pid_t,
    ) -> pid_t? {
        guard let focused = signals.focusedApplicationPID,
              focused != frontmostPID,
              focused != ownPID,
              signals.raisedWindows.contains(where: { isPanel($0, of: focused, in: signals) })
        else {
            return nil
        }
        return focused
    }

    /// Whether `window` is `pid`'s panel: not wholly inside the menu bar strip, and taller
    /// than ``minimumPanelHeight``.
    private static func isPanel(
        _ window: RaisedWindow,
        of pid: pid_t,
        in signals: TopmostContainerSignals,
    ) -> Bool {
        window.pid == pid
            && window.frame.maxY > signals.menuBarHeight
            && window.frame.height > minimumPanelHeight
    }

    /// The elements under `index`, re-rooted there: depth 0, no parent, and every other
    /// parent index shifted to match. Pre-order makes a subtree one contiguous run, which
    /// ends at the first later element no deeper than its root.
    private static func subtree(
        at index: Int,
        in elements: [ElementSnapshot],
    ) -> [ElementSnapshot] {
        let root = elements[index]
        let end = elements[(index + 1)...].firstIndex { $0.depth <= root.depth } ?? elements
            .endIndex
        return elements[index ..< end].map { element in
            ElementSnapshot(
                role: element.role,
                subrole: element.subrole,
                title: element.title,
                description: element.description,
                frame: element.frame,
                isEnabled: element.isEnabled,
                actions: element.actions,
                depth: element.depth - root.depth,
                parentIndex: element.depth == root.depth ? nil : element.parentIndex
                    .map { $0 - index },
            )
        }
    }
}
