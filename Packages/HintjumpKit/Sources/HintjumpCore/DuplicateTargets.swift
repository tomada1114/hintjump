import CoreGraphics

/// The duplicates among the clickable filter's admitted elements: the structural ones —
/// a window-sized pressable group, pressable content inside a button or link that is
/// itself a target, what is inside a row that is itself a target, and a row hidden under
/// its column header — and the frame key the ranker collapses same-frame twins by.
///
/// Measured in `docs/research/target-counts.md`: none of them reached the singles, but
/// they spent two-character labels (Finder's list view held 186 targets, about 74
/// without them) and stacked tags on one spot. A click lands at the survivor's visible
/// center either way, so which one survives decides only where its tag sits.
enum DuplicateTargets {
    /// A frame as a hashable value, so twins are found in one pass rather than by
    /// comparing every pair.
    struct FrameKey: Hashable {
        private let minX: CGFloat
        private let minY: CGFloat
        private let width: CGFloat
        private let height: CGFloat

        init(_ frame: CGRect) {
            minX = frame.minX
            minY = frame.minY
            width = frame.width
            height = frame.height
        }
    }

    /// The share of the read's root a pressable group must cover to be window-sized.
    static let windowSizedShare: CGFloat = 0.5

    /// The controls whose pressable content ``excludeControlContent(in:exclusions:)``
    /// drops.
    private static let contentOwningRoles: Set<String> = ["AXButton", "AXLink"]

    /// Marks, in `exclusions`, the window-sized groups, then the pressable content of a
    /// target button or link, then what is inside a target row, then the rows hidden
    /// under their column header — in that order, so a row dropped as a window-sized
    /// group is no target row and its cells stay reachable, while a row dropped under
    /// its header takes its cells with it: they share its hidden spot, and a click there
    /// would press the header just the same.
    ///
    /// A control's content comes right after the window-sized groups, so a group that
    /// is both keeps the reason that says more. No pass drops a button or a link — a
    /// window-sized group is never clickable by role, and the row passes drop only
    /// cells, text fields, and rows — so the control each piece of content defers to is
    /// final whichever order they run in.
    ///
    /// `exclusions` holds the filter's verdict for each element of `elements`, `nil` for
    /// an admitted one, and `root` is the frame of the read's root. Every pass is linear
    /// in the read, apart from a walk up from each cell and text field to its row.
    static func excludeStructural(
        in elements: [ElementSnapshot],
        root: CGRect,
        exclusions: inout [TargetExclusion?],
    ) {
        let holdsTarget = holdsAdmittedElement(elements, exclusions: exclusions)
        for index in elements.indices where exclusions[index] == nil && holdsTarget[index] {
            if isWindowSized(elementAt: index, in: elements, root: root) {
                exclusions[index] = .windowSizedGroup
            }
        }
        excludeControlContent(in: elements, exclusions: &exclusions)
        for index in elements.indices where exclusions[index] == nil {
            if isInsideTargetRow(elementAt: index, in: elements, exclusions: exclusions) {
                exclusions[index] = .insideTargetRow
            }
        }
        excludeRowsUnderColumnHeaders(in: elements, root: root, exclusions: &exclusions)
    }

    /// Whether each element has an admitted element somewhere below it.
    ///
    /// One walk up from each admitted element, stopping at the first container already
    /// marked — everything above it is marked too — so the whole pass is linear.
    private static func holdsAdmittedElement(
        _ elements: [ElementSnapshot],
        exclusions: [TargetExclusion?],
    ) -> [Bool] {
        var holds = Array(repeating: false, count: elements.count)
        for index in elements.indices where exclusions[index] == nil {
            var next = TargetRanker.parentIndex(ofElementAt: index, in: elements)
            while let parent = next, !holds[parent] {
                holds[parent] = true
                next = TargetRanker.parentIndex(ofElementAt: parent, in: elements)
            }
        }
        return holds
    }

    /// Admitted only through `AXPress` — its role alone would not be — and covering at
    /// least ``windowSizedShare`` of `root` with the part of its frame inside it.
    private static func isWindowSized(
        elementAt index: Int,
        in elements: [ElementSnapshot],
        root: CGRect,
    ) -> Bool {
        guard !TargetRanker.isClickableByRole(elementAt: index, in: elements),
              let frame = elements[index].frame
        else {
            return false
        }
        let covered = frame.intersection(root)
        return covered.width * covered.height >= windowSizedShare * root.width * root.height
    }

    /// Marks, in `exclusions`, each still-admitted element that is not clickable by role
    /// — so admitted only through `AXPress` — whose nearest control above it is an
    /// `AXButton` or an `AXLink` that is itself a target, as
    /// ``TargetExclusion/insideTargetControl``.
    ///
    /// The nearest control is the nearest container that is clickable by role, or an
    /// `AXRow` of any kind: content of a checkbox, a pop-up or menu button, or a row
    /// nested in the button belongs to that control, and its own rules. HTML allows no
    /// interactive content inside a button or a link, so what is pressable there is the
    /// control's own icon and text, and a click on it lands inside the control.
    private static func excludeControlContent(
        in elements: [ElementSnapshot],
        exclusions: inout [TargetExclusion?],
    ) {
        let byRole = elements.indices.map { index in
            TargetRanker.isClickableByRole(elementAt: index, in: elements)
        }
        let controls = nearestControls(in: elements, byRole: byRole)
        for index in elements.indices where exclusions[index] == nil && !byRole[index] {
            guard let control = controls[index],
                  contentOwningRoles.contains(elements[control].role ?? ""),
                  exclusions[control] == nil
            else {
                continue
            }
            exclusions[index] = .insideTargetControl
        }
    }

    /// The index of each element's nearest container that is clickable by role or is an
    /// `AXRow`, or `nil`.
    ///
    /// One forward pass: the pre-order puts a parent before its child, so the parent's
    /// answer is already known.
    private static func nearestControls(
        in elements: [ElementSnapshot],
        byRole: [Bool],
    ) -> [Int?] {
        var controls = [Int?](repeating: nil, count: elements.count)
        for index in elements.indices {
            guard let parent = TargetRanker.parentIndex(ofElementAt: index, in: elements) else {
                continue
            }
            let isControl = byRole[parent] || elements[parent].role == "AXRow"
            controls[index] = isControl ? parent : controls[parent]
        }
        return controls
    }

    /// An `AXCell`, or an `AXTextField` with an `AXCell` between it and its row, whose
    /// nearest `AXRow` is a target: admitted and not itself dropped.
    ///
    /// Every other control inside the row — a disclosure triangle, a checkbox, a pop-up
    /// button, a button — does something the row does not, so it is kept.
    private static func isInsideTargetRow(
        elementAt index: Int,
        in elements: [ElementSnapshot],
        exclusions: [TargetExclusion?],
    ) -> Bool {
        let role = elements[index].role
        guard role == "AXCell" || role == "AXTextField" else {
            return false
        }
        var isInCell = role == "AXCell"
        var current = index
        while let parent = TargetRanker.parentIndex(ofElementAt: current, in: elements) {
            switch elements[parent].role {
            case "AXRow":
                return isInCell && exclusions[parent] == nil

            case "AXCell":
                isInCell = true

            default:
                break
            }
            current = parent
        }
        return false
    }
}
