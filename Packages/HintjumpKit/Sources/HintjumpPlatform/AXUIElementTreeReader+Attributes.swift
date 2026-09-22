import ApplicationServices
import HintjumpCore

extension AXUIElementTreeReader {
    /// Everything one Accessibility element says about itself, before it becomes a value.
    ///
    /// The children are kept alongside the rest because a batched read fetches them in
    /// the same call; ``AXUIElementTreeReader/children(of:attributes:strategy:)`` decides
    /// whether they are the list the walk actually descends.
    struct Attributes {
        let role: String?
        let subrole: String?
        let title: String?
        let label: String?
        let frame: CGRect?
        let isEnabled: Bool
        let actions: [String]
        let childElements: [AXUIElement]

        func snapshot(depth: Int, parentIndex: Int?) -> ElementSnapshot {
            ElementSnapshot(
                role: role,
                subrole: subrole,
                title: title,
                description: label,
                frame: frame,
                isEnabled: isEnabled,
                actions: actions,
                depth: depth,
                parentIndex: parentIndex,
            )
        }
    }

    /// One element still to be visited, and where it sits in the flat list being built.
    private struct Pending {
        let element: AXUIElement
        let depth: Int
        let parentIndex: Int?
    }

    /// The attributes fetched for every element, in the order a batched read returns
    /// them. `AXChildren` is one of them so that a batched read costs exactly one call.
    static var attributeNames: [String] {
        [
            kAXRoleAttribute as String,
            kAXSubroleAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXPositionAttribute as String,
            kAXSizeAttribute as String,
            kAXEnabledAttribute as String,
            kAXChildrenAttribute as String,
        ]
    }

    /// Walks the tree under `root` iteratively and flattens it to pre-order.
    ///
    /// An explicit stack rather than recursion: a deep tree in a foreign process is not
    /// this process's stack to blow. Children are pushed in reverse so that popping
    /// yields them in the order the application reports, which makes the flat list
    /// pre-order — every parent precedes its children, and `parentIndex` always points
    /// backwards.
    ///
    /// When `strategy` prunes, the visible rectangle is the root's own frame, so a
    /// `.focusedWindow` or `.menuBar` read prunes against the window or the bar and an
    /// `.application` read — whose root has no frame — prunes nothing by rectangle and
    /// relies on the visible-children attributes alone. An element whose frame misses
    /// that rectangle is **still recorded**, and only its subtree is skipped: keeping
    /// the element makes a pruned read's element list comparable with an unpruned one
    /// instead of silently shorter at the top.
    static func walk(from root: AXUIElement, strategy: ReadStrategy) -> [ElementSnapshot] {
        var elements: [ElementSnapshot] = []
        var visibleRect: CGRect?
        var stack = [Pending(element: root, depth: 0, parentIndex: nil)]

        while let pending = stack.popLast() {
            let index = elements.count
            let read = attributes(of: pending.element, strategy: strategy)
            elements.append(read.snapshot(depth: pending.depth, parentIndex: pending.parentIndex))

            if index == 0 {
                visibleRect = strategy.prunesInvisibleSubtrees ? read.frame : nil
            } else if let visibleRect, let frame = read.frame, !frame.intersects(visibleRect) {
                continue
            }

            let next = children(of: pending.element, attributes: read, strategy: strategy)
            for child in next.reversed() {
                stack.append(
                    Pending(element: child, depth: pending.depth + 1, parentIndex: index),
                )
            }
        }
        return elements
    }

    /// Reads one element, in one call or in one call per attribute.
    ///
    /// The two paths must answer the same thing, which is what the read-latency
    /// verification compares: `.batched` is only allowed to be faster, never different.
    /// Actions are a separate call either way — `AXUIElementCopyActionNames` is not an
    /// attribute and has no batched form.
    static func attributes(of element: AXUIElement, strategy: ReadStrategy) -> Attributes {
        let values = strategy.readsAttributesInOneCall
            ? batchedValues(of: element)
            : individualValues(of: element)
        return Attributes(
            role: values[kAXRoleAttribute as String] as? String,
            subrole: values[kAXSubroleAttribute as String] as? String,
            title: values[kAXTitleAttribute as String] as? String,
            label: values[kAXDescriptionAttribute as String] as? String,
            frame: frame(from: values),
            isEnabled: values[kAXEnabledAttribute as String] as? Bool ?? true,
            actions: actionNames(of: element),
            childElements: values[kAXChildrenAttribute as String] as? [AXUIElement] ?? [],
        )
    }

    /// Which list of children a pruning walk descends.
    ///
    /// Selecting the attribute that holds the visible subset is translation, not a
    /// decision: the application is the one that knows which of its rows are on screen,
    /// and asking the attribute it publishes for that is reading its answer rather than
    /// forming one. `AXVisibleRows` first for a table or an outline, because those are
    /// the elements that publish thousands of rows and a handful of visible ones; then
    /// `AXVisibleChildren`; then everything.
    static func children(
        of element: AXUIElement,
        attributes: Attributes,
        strategy: ReadStrategy,
    ) -> [AXUIElement] {
        guard strategy.prunesInvisibleSubtrees else {
            return attributes.childElements
        }

        let rowContainers = [kAXTableRole as String, kAXOutlineRole as String]
        let holdsRows = attributes.role.map(rowContainers.contains) ?? false
        if holdsRows, let rows = elements(kAXVisibleRowsAttribute as String, of: element) {
            return rows
        }
        if let visible = elements(kAXVisibleChildrenAttribute as String, of: element) {
            return visible
        }
        return attributes.childElements
    }
}
