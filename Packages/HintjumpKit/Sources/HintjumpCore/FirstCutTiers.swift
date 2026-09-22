import CoreGraphics

/// The first-cut tier rule, and the predicates behind it.
///
/// Its own type, apart from ``TargetRanker``, so that replacing the rule is adding a
/// sibling of this type and passing its function to ``TargetRanker/init(assignTier:)``
/// — nothing about the filter, the order within a tier, or the output changes.
public enum FirstCutTiers {
    /// Roles a person types into.
    private static let textEntryRoles: Set<String> = ["AXSearchField", "AXTextArea", "AXTextField"]
    /// Roles drawn as a button. A radio button counts: in a toolbar it is a segment.
    private static let buttonRoles: Set<String> = [
        "AXButton", "AXMenuButton", "AXPopUpButton", "AXRadioButton",
    ]
    private static let rowOrCellRoles: Set<String> = ["AXCell", "AXRow"]
    /// Window subroles that mark a dialog, whose few buttons are nearly always the click.
    private static let dialogSubroles: Set<String> = ["AXDialog", "AXSystemDialog"]

    /// How far, in points, a sidebar's outline may start from the window's leading edge.
    /// Finder's starts 7 pt in, behind the window's inset.
    private static let sidebarLeadingTolerance: CGFloat = 16
    /// A sidebar is at most the window's width divided by this — a third. Structural
    /// rather than by `AXDescription`, which is localized ("Sidebar", "サイドバー").
    private static let sidebarWidthDivisor: CGFloat = 3

    /// The tier of `candidate`, deliberately simple — a guess the target-count
    /// measurement exists to correct, kept to this one function so correcting it touches
    /// nothing else.
    ///
    /// 1. ``TargetTier/primary``: text and search fields, tabs, a button inside a toolbar
    ///    or a dialog, and a sidebar row.
    /// 2. ``TargetTier/linkOrButton``: links and every other button.
    /// 3. ``TargetTier/rowOrCell``: rows and cells, and a text field inside a row — a
    ///    table's text field is how a row shows its name (every file in Finder's list
    ///    view has one), not an input, and ranking it with the inputs would spend the
    ///    single-character labels on it.
    /// 4. ``TargetTier/other``: everything else.
    @Sendable
    public static func tier(_ candidate: TargetCandidate) -> TargetTier {
        let role = candidate.element.role ?? ""
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
        (isTextEntry(candidate.element) && !isInsideRow(candidate))
            || isTab(candidate)
            || isToolbarOrDialogButton(candidate)
            || isSidebarRow(candidate)
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

    /// A button with a toolbar, a sheet, or a dialog window anywhere above it. The
    /// Accessibility API's `AXDefaultButton` would name the primary one exactly, but the
    /// snapshot does not carry it, and a dialog has few enough buttons that all of them
    /// can take the first tier.
    private static func isToolbarOrDialogButton(_ candidate: TargetCandidate) -> Bool {
        guard buttonRoles.contains(candidate.element.role ?? "") else {
            return false
        }
        return candidate.ancestors.contains { ancestor in
            switch ancestor.role {
            case "AXSheet", "AXToolbar":
                true

            case "AXWindow":
                dialogSubroles.contains(ancestor.subrole ?? "")

            default:
                false
            }
        }
    }

    /// A row of an outline or table that starts at the window's leading edge and takes
    /// at most a third of its width.
    private static func isSidebarRow(_ candidate: TargetCandidate) -> Bool {
        guard candidate.element.role == "AXRow",
              let container = candidate.ancestors.first,
              TargetRanker.rowContainerRoles.contains(container.role ?? ""),
              let frame = container.frame
        else {
            return false
        }
        let window = candidate.windowFrame
        return frame.minX - window.minX <= sidebarLeadingTolerance
            && frame.width <= window.width / sidebarWidthDivisor
    }
}
