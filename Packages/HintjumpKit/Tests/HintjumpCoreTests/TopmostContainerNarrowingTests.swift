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

    @Test
    func `a sheet wins over a popover inside it`() {
        let sheet = Self.root(
            role: "AXSheet",
            subrole: nil,
            children: [Self.popover(parent: 0, depth: 1)],
        )

        #expect(TopmostContainerRule.container(in: sheet).container == .sheet)
    }

    @Test
    func `the popover's subtree is re-rooted and ends at its last descendant`() {
        let narrowed = TopmostContainerRule
            .container(in: Self.windowWithPopover)

        #expect(narrowed.elements.map(\.role) == ["AXPopover", "AXButton", "AXCheckBox"])
        #expect(narrowed.elements.map(\.depth) == [0, 1, 1])
        #expect(narrowed.elements.map(\.parentIndex) == [nil, 0, 0])
    }

    @Test
    func `a popover that reports no frame, or an empty one, is not on screen`() {
        for frame in [nil, CGRect(x: 10, y: 10, width: 0, height: 0)] {
            let window = Self.window(children: [
                Self.element(
                    role: "AXPopover",
                    frame: frame,
                    depth: 1,
                    parent: 0,
                ),
            ])

            #expect(TopmostContainerRule.container(in: window).container == .focusedWindow)
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
