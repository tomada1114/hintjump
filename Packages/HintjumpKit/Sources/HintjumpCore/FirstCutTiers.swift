import CoreGraphics

/// The tier rule, and the predicates behind it: the first cut, revised by the
/// target-count measurement (`docs/research/target-counts.md`, `docs/decisions.md` ›
/// "The tier rule after #37's measurement; N stays 16").
///
/// Its own type, apart from ``TargetRanker``, so that replacing the rule is adding a
/// sibling of this type and passing its function to ``TargetRanker/init(assignTier:)``
/// — nothing about the filter, the order within a tier, or the output changes. The
/// measured revision edits this type in place rather than adding a sibling, since the
/// first cut has no caller left to keep it for.
public enum FirstCutTiers {
    /// Roles a person types into.
    private static let textEntryRoles: Set<String> = ["AXSearchField", "AXTextArea", "AXTextField"]
    /// Roles drawn as a button. A radio button counts: in a toolbar it is a segment.
    private static let buttonRoles: Set<String> = [
        "AXButton", "AXMenuButton", "AXPopUpButton", "AXRadioButton",
    ]
    private static let rowOrCellRoles: Set<String> = ["AXCell", "AXRow"]
    /// Subroles of a window's own close, minimize, zoom, and full-screen buttons: the
    /// window's frame, not what it is read for.
    private static let windowButtonSubroles: Set<String> = [
        "AXCloseButton", "AXFullScreenButton", "AXMinimizeButton", "AXZoomButton",
    ]
    /// Window subroles that mark a dialog, whose few buttons are nearly always the click.
    private static let dialogSubroles: Set<String> = ["AXDialog", "AXSystemDialog"]
    /// A web page's own header and navigation bar: the site's chrome, not what the page is
    /// read for. Nothing inside them is primary.
    private static let pageChromeSubroles: Set<String> = [
        "AXLandmarkBanner", "AXLandmarkNavigation",
    ]
    /// The landmark a web page marks its content with.
    private static let mainLandmarkSubrole = "AXLandmarkMain"
    private static let webAreaRole = "AXWebArea"
    /// The landmark a page marks an `<aside>` with — in a web app shell, its sidebar.
    private static let complementaryLandmarkSubrole = "AXLandmarkComplementary"
    /// Roles an app shell's sidebar entry takes: Claude Desktop's sessions are buttons,
    /// its settings entry a pop-up.
    private static let sidebarEntryRoles: Set<String> = ["AXButton", "AXLink", "AXPopUpButton"]
    /// A sidebar entry spans at least this share of its landmark's width, which admits
    /// the full-width entries and the settings pop-up (216 of 349 pt) and leaves the icon
    /// buttons and each entry's 30 pt "…" pop-up as plain buttons.
    private static let sidebarEntryMinimumWidthShare: CGFloat = 0.5
    /// How far an app shell's web area may sit from the window's top, leading, and
    /// trailing edges, in points.
    private static let appShellEdgeTolerance: CGFloat = 1

    /// A sidebar — an outline, or an app shell's complementary landmark — ends within the
    /// window's leading width divided by this (a third) wherever it starts, so one behind
    /// an icon rail (Slack's workspace rail, VS Code's activity bar) still counts.
    /// Structural rather than by `AXDescription`, which is localized ("Sidebar",
    /// "サイドバー").
    private static let sidebarWidthDivisor: CGFloat = 3
    /// How many containers up from a pressable element its row may be for the element to
    /// stand in for the row: VS Code's explorer presses a group two levels inside it.
    private static let rowStandInDepth = 2

    /// The tier of `candidate`, deliberately simple and kept to this one function so
    /// correcting it touches nothing else.
    ///
    /// 1. ``TargetTier/primary``: text and search fields, tabs, a button inside a sheet
    ///    or a dialog, a sidebar row, an entry in a web app shell's sidebar, and a link
    ///    in a web page's main content — but nothing inside a page's banner or
    ///    navigation landmark. A toolbar's buttons are not primary: measured, they took
    ///    the singles from the tabs, sidebars, and article links people click.
    /// 2. ``TargetTier/linkOrButton``: links and every other button.
    /// 3. ``TargetTier/rowOrCell``: rows and cells, and a text field inside a row — a
    ///    table's text field is how a row shows its name (every file in Finder's list
    ///    view has one), not an input, and ranking it with the inputs would spend the
    ///    single-character labels on it.
    /// 4. ``TargetTier/other``: everything else, and a window's own close, minimize,
    ///    zoom, and full-screen buttons in every kind of window — checked before tier 1,
    ///    since a dialog would otherwise make them primary with its other buttons.
    @Sendable
    public static func tier(_ candidate: TargetCandidate) -> TargetTier {
        let role = candidate.element.role ?? ""
        if windowButtonSubroles.contains(candidate.element.subrole ?? "") {
            return .other
        }
        if isPrimary(candidate) {
            return .primary
        }
        if role == "AXLink" || buttonRoles.contains(role) {
            return .linkOrButton
        }
        if rowOrCellRoles.contains(role) || isTextEntry(candidate.element) {
            return .rowOrCell
        }
        return .other
    }

    private static func isPrimary(_ candidate: TargetCandidate) -> Bool {
        guard !isInsidePageChrome(candidate) else {
            return false
        }
        return (isTextEntry(candidate.element) && !isInsideRow(candidate))
            || isTab(candidate)
            || isSheetOrDialogButton(candidate)
            || isSidebarRow(candidate)
            || isMainContentLink(candidate)
            || isAppShellSidebarEntry(candidate)
    }

    private static func isInsidePageChrome(_ candidate: TargetCandidate) -> Bool {
        candidate.ancestors.contains { pageChromeSubroles.contains($0.subrole ?? "") }
    }

    /// A link under a page's main landmark, in the page itself: exactly one web area
    /// above it, since a second one is an iframe — where ads are embedded.
    private static func isMainContentLink(_ candidate: TargetCandidate) -> Bool {
        guard candidate.element.role == "AXLink" else {
            return false
        }
        let webAreas = candidate.ancestors.count { $0.role == webAreaRole }
        return webAreas == 1
            && candidate.ancestors.contains { $0.subrole == mainLandmarkSubrole }
    }

    private static func isTextEntry(_ element: ElementSnapshot) -> Bool {
        textEntryRoles.contains(element.role ?? "") || element.subrole == "AXSearchField"
    }

    private static func isInsideRow(_ candidate: TargetCandidate) -> Bool {
        candidate.ancestors.contains { $0.role == "AXRow" }
    }

    /// An `AXTab`, a tab button, or a radio button directly in a tab group — the three
    /// shapes AppKit and SwiftUI tab views take.
    private static func isTab(_ candidate: TargetCandidate) -> Bool {
        let element = candidate.element
        if element.role == "AXTab" || element.subrole == "AXTabButton" {
            return true
        }
        return element.role == "AXRadioButton" && candidate.ancestors.first?.role == "AXTabGroup"
    }

    /// A button with a sheet or a dialog window anywhere above it. The Accessibility
    /// API's `AXDefaultButton` would name the primary one exactly, but the snapshot does
    /// not carry it, and a dialog has few enough buttons that all of them can take the
    /// first tier.
    private static func isSheetOrDialogButton(_ candidate: TargetCandidate) -> Bool {
        guard buttonRoles.contains(candidate.element.role ?? "") else {
            return false
        }
        return candidate.ancestors.contains { ancestor in
            switch ancestor.role {
            case "AXSheet":
                true

            case "AXWindow":
                dialogSubroles.contains(ancestor.subrole ?? "")

            default:
                false
            }
        }
    }

    /// A row whose nearest outline or table ends within the window's leading third, or a
    /// pressable element standing in for such a row.
    ///
    /// The element stands in for a row within ``rowStandInDepth`` containers above it
    /// when the clickable filter turns that row away — no `AXPress` and not directly in
    /// an outline or table, as in VS Code's explorer, or disabled, too small, or outside
    /// the window. The filter itself decides (``TargetRanker/admits(_:parent:root:)``),
    /// so this never disagrees with what becomes a target. When the row is a target,
    /// what is inside it keeps its own tier, so one row never takes two labels.
    private static func isSidebarRow(_ candidate: TargetCandidate) -> Bool {
        let ancestors = candidate.ancestors
        let aboveRow: ArraySlice<ElementSnapshot>
        if candidate.element.role == "AXRow" {
            aboveRow = ancestors[...]
        } else {
            let nearby = ancestors.prefix(rowStandInDepth)
            guard let rowIndex = nearby.firstIndex(where: { $0.role == "AXRow" }) else {
                return false
            }
            aboveRow = ancestors[(rowIndex + 1)...]
            let rowIsTarget = TargetRanker.admits(
                ancestors[rowIndex],
                parent: aboveRow.first,
                root: candidate.windowFrame,
            )
            guard !rowIsTarget else {
                return false
            }
        }
        let isContainer = { (element: ElementSnapshot) in
            TargetRanker.rowContainerRoles.contains(element.role ?? "")
        }
        guard let container = aboveRow.first(where: isContainer), let frame = container.frame else {
            return false
        }
        return isInLeadingThird(frame, of: candidate.windowFrame)
    }

    /// A button, link, or pop-up at least half as wide as its nearest complementary
    /// landmark, when that landmark ends within the window's leading third and the
    /// nearest web area above it is an app shell (``isAppShell(_:in:)``).
    ///
    /// Claude Desktop's sidebar is such a landmark, holding buttons in plain groups with
    /// no outline and no rows, so ``isSidebarRow(_:)`` does not see it. The guard keeps a
    /// website's own `<aside>` from taking the singles #37 gave its main content.
    private static func isAppShellSidebarEntry(_ candidate: TargetCandidate) -> Bool {
        let ancestors = candidate.ancestors
        let isLandmark = { (element: ElementSnapshot) in
            element.subrole == complementaryLandmarkSubrole
        }
        let isWebArea = { (element: ElementSnapshot) in element.role == webAreaRole }
        guard sidebarEntryRoles.contains(candidate.element.role ?? ""),
              let elementFrame = candidate.element.frame,
              let landmarkIndex = ancestors.firstIndex(where: isLandmark),
              let landmarkFrame = ancestors[landmarkIndex].frame,
              let webArea = ancestors[(landmarkIndex + 1)...].first(where: isWebArea),
              let webAreaFrame = webArea.frame
        else {
            return false
        }
        let window = candidate.windowFrame
        return isInLeadingThird(landmarkFrame, of: window)
            && elementFrame.width >= landmarkFrame.width * sidebarEntryMinimumWidthShare
            && isAppShell(webAreaFrame, in: window)
    }

    /// A web area whose top edge is at the window's top and which spans the window's
    /// width, each within ``appShellEdgeTolerance``: an Electron app's whole window. A
    /// browser's page always sits below its native tab bar and toolbar.
    private static func isAppShell(_ webArea: CGRect, in window: CGRect) -> Bool {
        abs(webArea.minY - window.minY) <= appShellEdgeTolerance
            && webArea.minX <= window.minX + appShellEdgeTolerance
            && webArea.maxX >= window.maxX - appShellEdgeTolerance
    }

    /// Whether `frame` ends within the window's leading third, wherever it starts.
    private static func isInLeadingThird(_ frame: CGRect, of window: CGRect) -> Bool {
        frame.maxX - window.minX <= window.width / sidebarWidthDivisor
    }
}
