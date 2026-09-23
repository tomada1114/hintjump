import CoreGraphics

/// A row hidden behind its column header (#98): Finder's list view reads its outline's
/// first row entirely under the header's sort buttons, and a click at that row's visible
/// center presses the "Name" button and re-sorts the list instead of selecting anything.
///
/// A column-header button of an `AXOutline` or `AXTable` is either an element with the
/// `AXSortButton` subrole anywhere under it — nearest first, so a nested table's header
/// is that table's — or an `AXButton` in a group directly in it: the header group
/// Finder reports as a plain `AXGroup` with no subrole, where a column that does not
/// sort would be a button without `AXSortButton`. Its frame counts whatever the filter
/// made of the button: a disabled one still covers the row.
extension DuplicateTargets {
    /// Marks, in `exclusions`, each still-admitted `AXRow` whose visible center —
    /// ``ClickPointRule``'s point inside `root`, where its click would land — lies inside
    /// a column-header button of its own nearest outline or table, as
    /// ``TargetExclusion/underColumnHeader``.
    ///
    /// Finder reads the header after the rows, so the header frames are collected in one
    /// pass and the rows tested in a second; with the nearest outline or table of every
    /// element found in a third before them, all three are linear in the read, each row
    /// checked against its own header's handful of buttons.
    static func excludeRowsUnderColumnHeaders(
        in elements: [ElementSnapshot],
        root: CGRect,
        exclusions: inout [TargetExclusion?],
    ) {
        let containers = nearestRowContainers(in: elements)
        let headers = columnHeaderFrames(in: elements, containers: containers)
        guard !headers.isEmpty else {
            return
        }
        for index in elements.indices where exclusions[index] == nil {
            guard elements[index].role == "AXRow",
                  let container = containers[index],
                  let buttons = headers[container],
                  let frame = elements[index].frame,
                  let clickPoint = ClickPointRule.point(for: frame, within: root)
            else {
                continue
            }
            if buttons.contains(where: { $0.contains(clickPoint) }) {
                exclusions[index] = .underColumnHeader
            }
        }
    }

    /// The index of each element's nearest `AXOutline` or `AXTable` above it, or `nil`.
    ///
    /// One forward pass: the pre-order puts a parent before its child, so the parent's
    /// answer is already known.
    private static func nearestRowContainers(in elements: [ElementSnapshot]) -> [Int?] {
        var containers = [Int?](repeating: nil, count: elements.count)
        for index in elements.indices {
            guard let parent = TargetRanker.parentIndex(ofElementAt: index, in: elements) else {
                continue
            }
            let isContainer = TargetRanker.rowContainerRoles.contains(elements[parent].role ?? "")
            containers[index] = isContainer ? parent : containers[parent]
        }
        return containers
    }

    /// The frames of each outline's or table's column-header buttons, by its index.
    private static func columnHeaderFrames(
        in elements: [ElementSnapshot],
        containers: [Int?],
    ) -> [Int: [CGRect]] {
        var headers: [Int: [CGRect]] = [:]
        for index in elements.indices {
            guard let container = containers[index],
                  let frame = elements[index].frame,
                  isColumnHeaderButton(elementAt: index, in: elements, container: container)
            else {
                continue
            }
            headers[container, default: []].append(frame)
        }
        return headers
    }

    /// Whether the element is a sort button, or an `AXButton` in a group directly in
    /// `container`, its nearest outline or table.
    private static func isColumnHeaderButton(
        elementAt index: Int,
        in elements: [ElementSnapshot],
        container: Int,
    ) -> Bool {
        let element = elements[index]
        if element.subrole == "AXSortButton" {
            return true
        }
        guard element.role == "AXButton",
              let group = TargetRanker.parentIndex(ofElementAt: index, in: elements),
              elements[group].role == "AXGroup"
        else {
            return false
        }
        return TargetRanker.parentIndex(ofElementAt: group, in: elements) == container
    }
}
