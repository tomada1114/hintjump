import Foundation
import HintjumpCore

/// A window, sheet, popover, drawer, or menu found in one application's tree, with how
/// many of its descendants the app would label.
struct Container {
    /// The roles that can be "whatever is on top". A dialog, a system dialog, or a
    /// floating panel is an `AXWindow` whose subrole says which.
    static let roles: Set<String> = ["AXDrawer", "AXMenu", "AXPopover", "AXSheet", "AXWindow"]

    /// The container's index in the read it came from.
    let index: Int
    let element: ElementSnapshot
    /// The container and everything read under it.
    let elementCount: Int
    /// `TargetRanker`'s targets in the subtree rooted at the container — the same
    /// clickable filter the app applies, with the container's frame as the bound, which
    /// is what a read rooted at the container (a #48 `ReadScope`) would rank.
    let clickable: Int

    /// Every container in `elements` — a pre-order read — that reports a non-empty
    /// frame. The frame test drops the closed menus under a menu bar's titles, which
    /// report a zero-size one; anything on screen has an area.
    static func find(in elements: [ElementSnapshot]) -> [Self] {
        let ranker = TargetRanker()
        return elements.indices.compactMap { index -> Self? in
            let candidate = elements[index]
            guard let role = candidate.role, roles.contains(role),
                  let frame = candidate.frame, !frame.isEmpty
            else {
                return nil
            }
            let subtree = subtree(at: index, in: elements)
            return Self(
                index: index,
                element: candidate,
                elementCount: subtree.count,
                clickable: ranker.rank(subtree).count,
            )
        }
    }

    /// The elements under `index`, re-rooted so the element at `index` is the root: its
    /// depth is 0, it has no parent, and every other parent index is shifted to match.
    ///
    /// Pre-order makes a subtree one contiguous run — it ends at the first later element
    /// no deeper than its root. It holds what a walk started at the container would
    /// read, except that nothing was pruned against the container's own rectangle (an
    /// application read has none), and that changes no count: `TargetRanker` drops
    /// every element whose center falls outside the root's frame either way.
    static func subtree(at index: Int, in elements: [ElementSnapshot]) -> [ElementSnapshot] {
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

    /// One greppable line: the pid the read was made against, then the container.
    func line(pid: pid_t) -> String {
        """
        container pid=\(pid) #\(index) depth=\(element.depth) \
        role=\(element.role ?? "-")/\(element.subrole ?? "-") \
        frame=\(formatted(element.frame)) elements=\(elementCount) clickable=\(clickable) \
        title=\(quoted(element.title))
        """
    }
}
