import ApplicationServices
import HintjumpCore

extension AXUIElementTreeReader {
    /// Everything one Accessibility element says about itself, before it becomes a value.
    ///
    /// The children are kept alongside the rest because a batched read fetches them in
    /// the same call, and so are the visible subsets a pruning read asks for:
    /// ``AXUIElementTreeReader/children(of:)`` decides which of the three lists the walk
    /// actually descends. `visibleRows` and `visibleChildren` are `nil` when the element
    /// does not publish the attribute (or the strategy never asked), and `[]` when it
    /// says nothing is visible — a pruning walk honours the second rather than falling
    /// back from it.
    struct Attributes {
        let role: String?
        let subrole: String?
        let title: String?
        let label: String?
        let frame: CGRect?
        let isEnabled: Bool
        let actions: [String]
        let childElements: [AXUIElement]
        // swiftlint:disable discouraged_optional_collection
        let visibleRows: [AXUIElement]?
        let visibleChildren: [AXUIElement]?
        // swiftlint:enable discouraged_optional_collection

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

    /// A frame no wider or no taller than this is a clipped sliver, not a place on screen.
    ///
    /// Chromium reports scrolled-away content clipped to 0–2 pt at the visible edge
    /// instead of placing it off screen the way WebKit and AppKit do, so the rectangle
    /// test alone keeps every one of those subtrees (`docs/research/read-latency.md`).
    /// Reading "clipped to nothing" as "not visible" is the same translation the
    /// rectangle test makes — where does the application say this element is — asked of
    /// the size instead of the position.
    static let clippedExtent: CGFloat = 2

    /// The roles whose visible subset is published as `AXVisibleRows`.
    static let rowContainerRoles = [kAXTableRole as String, kAXOutlineRole as String]

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

    /// The attributes a pruning read adds to the batched call, so that asking which
    /// children are on screen costs no round trip of its own. Chromium answers neither
    /// on its groups, and in one call that refusal is free.
    static var visibleSubsetAttributeNames: [String] {
        [
            kAXVisibleRowsAttribute as String,
            kAXVisibleChildrenAttribute as String,
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
    /// that rectangle, or is clipped to a sliver (``clippedExtent``), is **still
    /// recorded**, and only its subtree is skipped: keeping the element makes a pruned
    /// read's element list comparable with an unpruned one instead of silently shorter
    /// at the top.
    static func walk(from root: AXUIElement, strategy: ReadStrategy) -> [ElementSnapshot] {
        var elements: [ElementSnapshot] = []
        var visibleRect: CGRect?
        var stack = [Pending(element: root, depth: 0, parentIndex: nil)]
        let prunes = strategy.prunesInvisibleSubtrees

        while let pending = stack.popLast() {
            let index = elements.count
            let read = attributes(of: pending.element, strategy: strategy)
            elements.append(read.snapshot(depth: pending.depth, parentIndex: pending.parentIndex))

            if index == 0 {
                visibleRect = prunes ? read.frame : nil
            } else if prunes, isOutOfView(read.frame, within: visibleRect) {
                continue
            }

            for child in children(of: read).reversed() {
                stack.append(
                    Pending(element: child, depth: pending.depth + 1, parentIndex: index),
                )
            }
        }
        return elements
    }

    /// Whether the application places `frame` where nothing of it can be seen: outside
    /// `visibleRect` when there is one, or clipped to a sliver whichever way. No frame
    /// at all is not "out of view": an element that reports no position is a container
    /// whose children may well have one.
    static func isOutOfView(_ frame: CGRect?, within visibleRect: CGRect?) -> Bool {
        guard let frame else {
            return false
        }
        if frame.width <= clippedExtent || frame.height <= clippedExtent {
            return true
        }
        guard let visibleRect else {
            return false
        }
        return !frame.intersects(visibleRect)
    }

    /// Reads one element, in one call or in one call per attribute.
    ///
    /// The two paths must answer the same thing, which is what the read-latency
    /// verification compares: `.batched` is only allowed to be faster, never different.
    /// Actions are a separate call either way — `AXUIElementCopyActionNames` is not an
    /// attribute and has no batched form.
    ///
    /// A pruning read also asks for the visible subsets. Batched, they ride in the same
    /// call as everything else; one attribute at a time, `AXVisibleRows` is asked only
    /// of a table or an outline and `AXVisibleChildren` only when that gave no answer,
    /// so the unbatched path pays for nothing it will not use.
    static func attributes(of element: AXUIElement, strategy: ReadStrategy) -> Attributes {
        let names = strategy.prunesInvisibleSubtrees
            ? attributeNames + visibleSubsetAttributeNames
            : attributeNames
        let values = strategy.readsAttributesInOneCall
            ? batchedValues(of: element, names: names)
            : individualValues(of: element, names: attributeNames)
        let role = values[kAXRoleAttribute as String] as? String
        let visible = visibleSubsets(of: element, role: role, values: values, strategy: strategy)
        return Attributes(
            role: role,
            subrole: values[kAXSubroleAttribute as String] as? String,
            title: values[kAXTitleAttribute as String] as? String,
            label: values[kAXDescriptionAttribute as String] as? String,
            frame: frame(from: values),
            isEnabled: values[kAXEnabledAttribute as String] as? Bool ?? true,
            actions: actionNames(of: element),
            childElements: values[kAXChildrenAttribute as String] as? [AXUIElement] ?? [],
            visibleRows: visible.rows,
            visibleChildren: visible.children,
        )
    }

    // swiftlint:disable discouraged_optional_collection
    /// The visible-subset answers for one element, from the batched dictionary or from
    /// the individual calls the unbatched pruning path makes; both `nil` when the
    /// strategy does not prune.
    private static func visibleSubsets(
        of element: AXUIElement,
        role: String?,
        values: [String: AnyObject],
        strategy: ReadStrategy,
    ) -> (rows: [AXUIElement]?, children: [AXUIElement]?) {
        guard strategy.prunesInvisibleSubtrees else {
            return (nil, nil)
        }
        if strategy.readsAttributesInOneCall {
            return (
                values[kAXVisibleRowsAttribute as String] as? [AXUIElement],
                values[kAXVisibleChildrenAttribute as String] as? [AXUIElement],
            )
        }
        let holdsRows = role.map(rowContainerRoles.contains) ?? false
        let rows = holdsRows ? elements(kAXVisibleRowsAttribute as String, of: element) : nil
        if let rows {
            return (rows, nil)
        }
        return (nil, elements(kAXVisibleChildrenAttribute as String, of: element))
    }

    // swiftlint:enable discouraged_optional_collection

    /// Which list of children a walk descends.
    ///
    /// Selecting the attribute that holds the visible subset is translation, not a
    /// decision: the application is the one that knows which of its rows are on screen,
    /// and asking the attribute it publishes for that is reading its answer rather than
    /// forming one. `AXVisibleRows` first for a table or an outline, because those are
    /// the elements that publish thousands of rows and a handful of visible ones; then
    /// `AXVisibleChildren`; then everything. A non-pruning read never asked for the
    /// first two, so it descends everything.
    static func children(of attributes: Attributes) -> [AXUIElement] {
        let holdsRows = attributes.role.map(rowContainerRoles.contains) ?? false
        if holdsRows, let rows = attributes.visibleRows {
            return rows
        }
        return attributes.visibleChildren ?? attributes.childElements
    }
}
