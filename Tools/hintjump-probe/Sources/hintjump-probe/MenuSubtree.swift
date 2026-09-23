import ApplicationServices
import HintjumpCore

/// The elements under a menu the probe found by hit-testing, as `ElementSnapshot`s
/// `TargetRanker` can rank.
///
/// Why a walk of the probe's own: `front` reads the menu its own hit test found, the
/// `AXUIElement` it already holds, and prints that hit test's chain alongside the count.
/// `AXUIElementTreeReader` can now start at the same menu (`ReadScope.popUpMenu`, #48, or
/// `dump --scope popup`), but only by hit-testing again. The walk reads the same
/// attributes the adapter reads, one call each, and prunes the same way its pruning
/// strategies do: an element clipped to a sliver is recorded and not descended. The
/// clickable decision stays `TargetRanker`'s.
enum MenuSubtree {
    private struct Pending {
        let element: AXUIElement
        let depth: Int
        let parentIndex: Int?
    }

    /// A bound on the walk, far above the largest menu seen (43 items); it only guards
    /// against an application that answers with a cycle.
    static let maximumElements = 500
    /// The adapter's sliver, `AXUIElementTreeReader.clippedExtent`, which is internal to
    /// its package.
    static let clippedExtent: CGFloat = 2

    /// `menu` and everything under it, in pre-order, root first.
    static func snapshots(from menu: AXUIElement) -> [ElementSnapshot] {
        var elements: [ElementSnapshot] = []
        var stack = [Pending(element: menu, depth: 0, parentIndex: nil)]
        while let pending = stack.popLast(), elements.count < maximumElements {
            let index = elements.count
            let snapshot = snapshot(of: pending)
            elements.append(snapshot)
            if isSliver(snapshot.frame) {
                continue
            }
            let children = AXRaw.elements(kAXChildrenAttribute, of: pending.element)
            for child in children.reversed() {
                stack.append(Pending(element: child, depth: pending.depth + 1, parentIndex: index))
            }
        }
        return elements
    }

    private static func isSliver(_ frame: CGRect?) -> Bool {
        guard let frame else {
            return false
        }
        return frame.width <= clippedExtent || frame.height <= clippedExtent
    }

    private static func snapshot(of pending: Pending) -> ElementSnapshot {
        let element = pending.element
        var names: CFArray?
        let actions = AXUIElementCopyActionNames(element, &names) == .success
            ? names as? [String] ?? []
            : []
        return ElementSnapshot(
            role: AXRaw.string(kAXRoleAttribute, of: element),
            subrole: AXRaw.string(kAXSubroleAttribute, of: element),
            title: AXRaw.string(kAXTitleAttribute, of: element),
            description: AXRaw.string(kAXDescriptionAttribute, of: element),
            frame: AXRaw.frame(of: element),
            // As the adapter does: an element that does not report `AXEnabled` is enabled.
            isEnabled: AXRaw.value(kAXEnabledAttribute, of: element) as? Bool ?? true,
            actions: actions,
            depth: pending.depth,
            parentIndex: pending.parentIndex,
        )
    }
}
