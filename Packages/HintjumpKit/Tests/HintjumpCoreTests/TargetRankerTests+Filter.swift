import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    @Suite("clickable filter")
    struct Filter {
        @Test
        func `an empty snapshot ranks nothing`() {
            #expect(TargetRanker().rank([]).isEmpty)
        }

        @Test
        func `a window with no clickable element ranks nothing, and the window itself is not a target`() {
            let elements = tree([])
            #expect(TargetRanker().rank(elements).isEmpty)
            #expect(TargetRanker.exclusion(ofElementAt: 0, in: elements) == .notClickable)
        }

        @Test(
            arguments: [
                "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXSearchField", "AXCheckBox",
                "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXTab", "AXCell",
                "AXDisclosureTriangle", "AXComboBox", "AXSlider", "AXIncrementor",
            ],
        )
        func `each listed role is clickable without an AXPress action`(role: String) {
            let elements = tree([Spec(role: role)])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == nil)
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [1])
        }

        @Test
        func `any role with an AXPress action is clickable`() {
            let elements = tree([Spec(role: "AXStaticText", actions: ["AXShowMenu", "AXPress"])])
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [1])
        }

        @Test(arguments: ["AXOutline", "AXTable"])
        func `an AXRow is clickable in an outline or a table`(container: String) {
            let elements = tree([
                Spec(role: container, frame: rect(300, 50, 500, 500)),
                Spec(role: "AXRow", frame: rect(300, 50, 500, 30), parent: 1),
            ])
            #expect(TargetRanker.exclusion(ofElementAt: 2, in: elements) == nil)
        }

        @Test
        func `an AXRow outside an outline or a table is not clickable`() {
            let elements = tree([
                Spec(role: "AXList", frame: rect(300, 50, 500, 500)),
                Spec(role: "AXRow", frame: rect(300, 50, 500, 30), parent: 1),
            ])
            #expect(TargetRanker.exclusion(ofElementAt: 2, in: elements) == .notClickable)
            #expect(TargetRanker().rank(elements).isEmpty)
        }

        @Test(
            arguments: ["AXStaticText", "AXImage", "AXGroup", nil] as [String?],
        )
        func `an unlisted role with no AXPress, or no role at all, is not clickable`(role: String?) {
            let elements = tree([Spec(role: role, actions: ["AXShowMenu"])])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == .notClickable)
            #expect(TargetRanker().rank(elements).isEmpty)
        }

        @Test
        func `a disabled element is excluded`() {
            let elements = tree([Spec(isEnabled: false, actions: ["AXPress"])])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == .disabled)
            #expect(TargetRanker().rank(elements).isEmpty)
        }

        @Test
        func `an element with no frame is excluded`() {
            let elements = tree([Spec(frame: nil)])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == .noFrame)
            #expect(TargetRanker().rank(elements).isEmpty)
        }

        @Test(
            arguments: [
                (CGSize(width: 8, height: 8), nil),
                (CGSize(width: 7.9, height: 8), TargetExclusion.tooSmall),
                (CGSize(width: 8, height: 7.9), TargetExclusion.tooSmall),
                (CGSize.zero, TargetExclusion.tooSmall),
            ] as [(CGSize, TargetExclusion?)],
        )
        func `the 8 × 8 pt minimum is inclusive on both axes`(
            size: CGSize,
            expected: TargetExclusion?,
        ) {
            let elements = tree([Spec(frame: CGRect(origin: CGPoint(x: 100, y: 100), size: size))])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == expected)
            #expect(TargetRanker().rank(elements).count == (expected == nil ? 1 : 0))
        }

        @Test(
            arguments: [
                // Center exactly on the window's leading and top edges: inside.
                (rect(-20, -10, 40, 20), nil),
                // Half off the trailing edge, center still inside.
                (rect(880, 300, 30, 20), nil),
                // Center exactly on the trailing edge: outside, as CGRect.contains says.
                (rect(880, 300, 40, 20), TargetExclusion.outsideWindow),
                // Scrolled below the window.
                (rect(100, 700, 40, 20), TargetExclusion.outsideWindow),
                // Left of the window.
                (rect(-100, 100, 40, 20), TargetExclusion.outsideWindow),
            ] as [(CGRect, TargetExclusion?)],
        )
        func `an element is inside the window when its center is`(
            frame: CGRect,
            expected: TargetExclusion?,
        ) {
            let elements = tree([Spec(frame: frame)])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == expected)
        }

        @Test
        func `with no window frame, nothing is inside the window`() {
            let elements = tree([Spec()], rootFrame: nil, rootSubrole: "AXStandardWindow")
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == .outsideWindow)
            #expect(TargetRanker().rank(elements).isEmpty)
        }

        @Test
        func `the first failing reason is reported: not clickable before disabled before size`() {
            let elements = tree([
                Spec(role: "AXImage", frame: nil, isEnabled: false),
                Spec(frame: nil, isEnabled: false),
                Spec(frame: rect(2_000, 2_000, 1, 1)),
            ])
            #expect(TargetRanker.exclusion(ofElementAt: 1, in: elements) == .notClickable)
            #expect(TargetRanker.exclusion(ofElementAt: 2, in: elements) == .disabled)
            #expect(TargetRanker.exclusion(ofElementAt: 3, in: elements) == .tooSmall)
        }

        @Test
        func `a parent index that does not precede its child is treated as no parent`() {
            var elements = tree([Spec(role: "AXOutline", frame: rect(0, 0, 900, 600))])
            elements.append(
                ElementSnapshot(
                    role: "AXRow",
                    subrole: nil,
                    title: nil,
                    description: nil,
                    frame: rect(0, 0, 900, 30),
                    isEnabled: true,
                    actions: [],
                    depth: 2,
                    parentIndex: 2,
                ),
            )
            #expect(TargetRanker.exclusion(ofElementAt: 2, in: elements) == .notClickable)
            #expect(TargetRanker().rank(elements).isEmpty)
        }
    }
}
