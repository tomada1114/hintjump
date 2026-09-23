import CoreGraphics
import HintjumpCore
import Testing

/// Checks 3 to 5 of `TopmostContainerRule`: a focused window's read narrowed to its sheet
/// or popover, over reads shaped like the ones #9 recorded. The fixtures are shared with
/// `TopmostContainerRuleTests` and `WindowTargetCollectorTopmostTests`.
@Suite("TopmostContainerRule › narrowing a focused window's read")
struct TopmostContainerNarrowingTests {
    static let windowFrame = CGRect(x: 0, y: 0, width: 900, height: 600)
    /// Finder's Tags popover, hanging from the toolbar.
    static let popoverFrame = CGRect(x: 500, y: 60, width: 260, height: 300)

    /// A window whose toolbar holds a button, a popover two levels down holding a button
    /// and a checkbox, and a window button after the popover.
    static let windowWithPopover = window(children: [
        element(
            role: "AXToolbar",
            frame: CGRect(x: 0, y: 0, width: 900, height: 52),
            depth: 1,
            parent: 0,
        ),
        button(parent: 1, frame: CGRect(x: 520, y: 14, width: 30, height: 24)),
        element(role: "AXGroup", frame: popoverFrame, depth: 2, parent: 1),
        popover(parent: 3, depth: 3),
        element(
            role: "AXButton",
            frame: CGRect(x: 520, y: 80, width: 200, height: 22),
            depth: 4,
            parent: 4,
        ),
        element(
            role: "AXCheckBox",
            frame: CGRect(x: 520, y: 120, width: 200, height: 22),
            depth: 4,
            parent: 4,
        ),
        button(parent: 0, frame: CGRect(x: 20, y: 560, width: 40, height: 20)),
    ])

    /// A popover opened from a control in a sheet: a button, the popover holding a button
    /// and a checkbox, and a button after the popover.
    static let sheetWithPopover = root(
        role: "AXSheet",
        subrole: nil,
        children: [
            button(parent: 0),
            popover(parent: 0, depth: 1),
            element(
                role: "AXButton",
                frame: CGRect(x: 520, y: 80, width: 200, height: 22),
                depth: 2,
                parent: 2,
            ),
            element(
                role: "AXCheckBox",
                frame: CGRect(x: 520, y: 120, width: 200, height: 22),
                depth: 2,
                parent: 2,
            ),
            button(parent: 0, frame: CGRect(x: 20, y: 560, width: 40, height: 20)),
        ],
    )

    /// The popover opened from inside the Tags popover, off its right edge.
    static let innerPopoverFrame = CGRect(x: 760, y: 100, width: 220, height: 120)

    static func element(
        role: String,
        frame: CGRect?,
        depth: Int,
        parent: Int?,
    ) -> ElementSnapshot {
        ElementSnapshot(
            role: role,
            subrole: nil,
            title: nil,
            description: nil,
            frame: frame,
            isEnabled: true,
            actions: role == "AXButton" || role == "AXCheckBox" ? ["AXPress"] : [],
            depth: depth,
            parentIndex: parent,
        )
    }

    static func root(
        role: String,
        subrole: String?,
        children: [ElementSnapshot],
    ) -> [ElementSnapshot] {
        let root = ElementSnapshot(
            role: role,
            subrole: subrole,
            title: nil,
            description: nil,
            frame: windowFrame,
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        return [root] + children
    }

    static func window(children: [ElementSnapshot]) -> [ElementSnapshot] {
        root(role: "AXWindow", subrole: "AXStandardWindow", children: children)
    }

    /// A button under `parent`, near the window's top-left corner.
    static func button(parent: Int) -> ElementSnapshot {
        button(parent: parent, frame: CGRect(x: 20, y: 20, width: 40, height: 20))
    }

    static func button(parent: Int, frame: CGRect) -> ElementSnapshot {
        element(role: "AXButton", frame: frame, depth: parent + 1, parent: parent)
    }

    static func popover(parent: Int, depth: Int) -> ElementSnapshot {
        element(role: "AXPopover", frame: popoverFrame, depth: depth, parent: parent)
    }

    /// A popover opened from inside another one, whose frame is `innerFrame`: the outer
    /// popover holds a button, the inner popover (a button and a checkbox), and a button
    /// after the inner popover.
    static func windowWithNestedPopover(innerFrame: CGRect?) -> [ElementSnapshot] {
        window(children: [
            popover(parent: 0, depth: 1),
            element(
                role: "AXButton",
                frame: CGRect(x: 520, y: 80, width: 200, height: 22),
                depth: 2,
                parent: 1,
            ),
            element(role: "AXPopover", frame: innerFrame, depth: 2, parent: 1),
            element(
                role: "AXButton",
                frame: CGRect(x: 780, y: 120, width: 180, height: 22),
                depth: 3,
                parent: 3,
            ),
            element(
                role: "AXCheckBox",
                frame: CGRect(x: 780, y: 160, width: 180, height: 22),
                depth: 3,
                parent: 3,
            ),
            element(
                role: "AXButton",
                frame: CGRect(x: 520, y: 320, width: 200, height: 22),
                depth: 2,
                parent: 1,
            ),
        ])
    }

    @Test
    func `a popover opened inside a sheet is narrowed to, not the sheet behind it`() throws {
        let narrowed = TopmostContainerRule.container(in: Self.sheetWithPopover)

        #expect(narrowed.container == .popover)
        #expect(narrowed.elements.map(\.role) == ["AXPopover", "AXButton", "AXCheckBox"])
        #expect(narrowed.elements.map(\.parentIndex) == [nil, 0, 0])
        let root = try #require(narrowed.elements.first)
        #expect(root.frame == Self.popoverFrame)
    }

    @Test
    func `a sheet with no popover open in it is the sheet, whole`() {
        let sheet = Self.root(
            role: "AXSheet",
            subrole: nil,
            children: [Self.button(parent: 0)],
        )
        let narrowed = TopmostContainerRule.container(in: sheet)

        #expect(narrowed.container == .sheet)
        #expect(narrowed.elements == sheet)
    }

    @Test
    func `a popover nested in a popover is narrowed to the inner one`() throws {
        let narrowed = TopmostContainerRule
            .container(in: Self.windowWithNestedPopover(innerFrame: Self.innerPopoverFrame))

        #expect(narrowed.container == .popover)
        #expect(narrowed.elements.map(\.role) == ["AXPopover", "AXButton", "AXCheckBox"])
        #expect(narrowed.elements.map(\.depth) == [0, 1, 1])
        #expect(narrowed.elements.map(\.parentIndex) == [nil, 0, 0])
        let root = try #require(narrowed.elements.first)
        #expect(root.frame == Self.innerPopoverFrame)
    }

    @Test(arguments: [nil, CGRect(x: 760, y: 100, width: 0, height: 0)])
    func `a frameless inner popover gives way to the outer one`(innerFrame: CGRect?) throws {
        let narrowed = TopmostContainerRule
            .container(in: Self.windowWithNestedPopover(innerFrame: innerFrame))

        #expect(narrowed.container == .popover)
        #expect(narrowed.elements.map(\.role) == [
            "AXPopover", "AXButton", "AXPopover", "AXButton", "AXCheckBox", "AXButton",
        ])
        let root = try #require(narrowed.elements.first)
        #expect(root.frame == Self.popoverFrame)
    }

    @Test
    func `the popover's subtree is re-rooted and ends at its last descendant`() {
        let narrowed = TopmostContainerRule
            .container(in: Self.windowWithPopover)

        #expect(narrowed.elements.map(\.role) == ["AXPopover", "AXButton", "AXCheckBox"])
        #expect(narrowed.elements.map(\.depth) == [0, 1, 1])
        #expect(narrowed.elements.map(\.parentIndex) == [nil, 0, 0])
    }

    @Test(arguments: [
        ("AXWindow", TopmostContainer.focusedWindow),
        ("AXSheet", TopmostContainer.sheet),
    ])
    func `a popover that reports no frame, or an empty one, is not on screen`(
        rootRole: String,
        expected: TopmostContainer,
    ) {
        for frame in [nil, CGRect(x: 10, y: 10, width: 0, height: 0)] {
            let read = Self.root(role: rootRole, subrole: nil, children: [
                Self.element(
                    role: "AXPopover",
                    frame: frame,
                    depth: 1,
                    parent: 0,
                ),
            ])

            #expect(TopmostContainerRule.container(in: read).container == expected)
        }
    }

    @Test
    func `an empty read is the focused window with nothing in it`() {
        let narrowed = TopmostContainerRule.container(in: [])

        #expect(narrowed.container == .focusedWindow)
        #expect(narrowed.elements.isEmpty)
    }

    @Test
    func `each container names the scope its read starts from`() {
        #expect(TopmostContainer.contextMenu.scope == .popUpMenu)
        for container in [TopmostContainer.otherProcessPanel, .sheet, .popover, .focusedWindow] {
            #expect(container.scope == .focusedWindow)
        }
    }
}
