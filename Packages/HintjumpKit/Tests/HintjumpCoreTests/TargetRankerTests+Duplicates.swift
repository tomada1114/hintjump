import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// The duplicates the ranker collapses after the clickable filter
    /// (`docs/research/target-counts.md` › Follow-ups): a target row's cells and name
    /// field, window-sized pressable groups, and targets sharing one frame.
    @Suite("duplicates")
    struct Duplicates {
        /// Finder's list view: a wide outline right of the sidebar.
        private static let content = Spec(role: "AXOutline", frame: rect(230, 50, 660, 540))

        /// One file of Finder's list view: its row directly in the outline, five cells, and
        /// the name field inside the first cell — seven targets before this rule.
        private static let finderRow: [Spec] = [
            content,
            Spec(role: "AXRow", frame: rect(230, 80, 660, 20), parent: 1),
            Spec(role: "AXCell", frame: rect(230, 80, 300, 20), parent: 2),
            Spec(role: "AXTextField", frame: rect(270, 82, 200, 16), parent: 3),
            Spec(role: "AXCell", frame: rect(530, 80, 140, 20), parent: 2),
            Spec(role: "AXCell", frame: rect(670, 80, 80, 20), parent: 2),
            Spec(role: "AXCell", frame: rect(750, 80, 100, 20), parent: 2),
            Spec(role: "AXCell", frame: rect(850, 80, 40, 20), parent: 2),
        ]

        /// Electron's shape: a pressable group of `groupFrame` holding a web area with a
        /// button inside it.
        private static func electron(groupFrame: CGRect, role: String = "AXGroup") -> [Spec] {
            [
                Spec(role: role, frame: groupFrame, actions: ["AXPress"]),
                Spec(role: "AXWebArea", frame: rect(0, 40, 900, 560), parent: 1),
                Spec(frame: rect(100, 100, 40, 20), parent: 2),
            ]
        }

        // MARK: - A target row's cells

        @Test
        func `a Finder list row with cells and a name field ranks only the row`() {
            let elements = tree(Self.finderRow)
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.targets.map(\.elementIndex) == [2])
            #expect(ranking.targets.map(\.rank) == [1])
            for index in 3 ... 8 {
                #expect(ranking.exclusions[index] == .insideTargetRow)
            }
            #expect(TargetRanker().rank(elements) == ranking.targets)
        }

        @Test(arguments: ["AXDisclosureTriangle", "AXCheckBox", "AXPopUpButton", "AXButton"])
        func `a control inside a target row's cell is kept`(role: String) {
            var specs = Self.finderRow
            specs.append(Spec(role: role, frame: rect(234, 84, 12, 12), parent: 3))
            let elements = tree(specs)
            let ranking = TargetRanker().ranking(elements)
            #expect(Set(ranking.targets.map(\.elementIndex)) == [2, 9])
            #expect(ranking.exclusions[9] == nil)
        }

        @Test
        func `a cell and its name field in a row that is not a target are kept`() {
            // No AXPress, and in a list rather than an outline or a table: the filter
            // turns the row away, so its cell and name field are how it is reached.
            let elements = tree([
                Spec(role: "AXList", frame: rect(230, 50, 660, 540)),
                Spec(role: "AXRow", frame: rect(230, 80, 660, 20), parent: 1),
                Spec(role: "AXCell", frame: rect(230, 80, 300, 20), parent: 2),
                Spec(role: "AXTextField", frame: rect(270, 82, 200, 16), parent: 3),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(Set(ranking.targets.map(\.elementIndex)) == [3, 4])
            #expect(ranking.exclusions[2] == .notClickable)
        }

        @Test
        func `a text field in a target row but outside any cell is kept`() {
            let elements = tree([
                Self.content,
                Spec(role: "AXRow", frame: rect(230, 80, 660, 20), parent: 1),
                Spec(role: "AXTextField", frame: rect(270, 82, 200, 16), parent: 2),
            ])
            #expect(Set(TargetRanker().rank(elements).map(\.elementIndex)) == [2, 3])
        }

        @Test
        func `a sidebar row's same-size cell is reported as inside the row, not as a twin`() {
            let frame = rect(7, 80, 220, 24)
            let elements = tree([
                Spec(role: "AXOutline", frame: rect(7, 50, 220, 540)),
                Spec(role: "AXRow", frame: frame, parent: 1),
                Spec(role: "AXCell", frame: frame, parent: 2),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.targets.map(\.elementIndex) == [2])
            #expect(ranking.targets.map(\.tier) == [.primary])
            #expect(ranking.exclusions[3] == .insideTargetRow)
        }

        @Test
        func `the clickable filter alone still admits a target row's cell`() {
            #expect(TargetRanker.exclusion(ofElementAt: 3, in: tree(Self.finderRow)) == nil)
        }

        // MARK: - Same frame

        @Test
        func `two targets with one frame keep the better-ranked, whatever the tree order`() {
            let frame = rect(10, 60, 200, 28)
            let elements = tree([
                Spec(role: "AXGroup", frame: frame, actions: ["AXPress"]),
                Spec(role: "AXLink", frame: frame),
                Spec(role: "AXLink", frame: rect(10, 300, 60, 20)),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.targets.map(\.elementIndex) == [2, 3])
            #expect(ranking.targets.map(\.rank) == [1, 2])
            #expect(ranking.exclusions[1] == .sameFrame)
            #expect(ranking.exclusions[2] == nil)
        }

        @Test
        func `twins in one tier keep the first in tree order`() {
            let frame = rect(100, 100, 40, 20)
            let elements = tree([Spec(frame: frame), Spec(frame: frame), Spec(frame: frame)])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.targets.map(\.elementIndex) == [1])
            #expect(ranking.exclusions[2] == .sameFrame)
            #expect(ranking.exclusions[3] == .sameFrame)
        }

        @Test
        func `frames that differ by any edge are not twins`() {
            let elements = tree([
                Spec(frame: rect(100, 100, 40, 20)),
                Spec(frame: rect(100, 100, 40, 20.5)),
                Spec(frame: rect(100.5, 100, 40, 20)),
            ])
            #expect(TargetRanker().rank(elements).count == 3)
        }

        // MARK: - Window-sized pressable groups

        @Test(
            arguments: [
                // The whole window.
                (windowFrame, TargetExclusion.windowSizedGroup),
                // Exactly half of it.
                (rect(0, 0, 450, 600), .windowSizedGroup),
                // Taller than the window, still covering all of it.
                (rect(0, -600, 900, 1_800), .windowSizedGroup),
                // Just under half.
                (rect(0, 0, 449, 600), nil),
                // Larger than half the window, but only 280 of its 540 pt are inside it.
                (rect(0, 320, 900, 540), nil),
            ] as [(CGRect, TargetExclusion?)],
        )
        func `a pressable group is window-sized when it covers half the read's root`(
            groupFrame: CGRect,
            expected: TargetExclusion?,
        ) {
            let ranking = TargetRanker().ranking(tree(Self.electron(groupFrame: groupFrame)))
            #expect(ranking.exclusions[1] == expected)
            #expect(ranking.exclusions[3] == nil)
            #expect(ranking.targets.count == (expected == nil ? 2 : 1))
        }

        @Test
        func `a window-sized pressable group with no target inside it is kept`() {
            let elements = tree([
                Spec(role: "AXGroup", frame: windowFrame, actions: ["AXPress"]),
                Spec(role: "AXStaticText", frame: rect(100, 100, 40, 20), parent: 1),
                Spec(frame: rect(100, 100, 40, 20), isEnabled: false, parent: 1),
            ])
            #expect(TargetRanker().rank(elements).map(\.elementIndex) == [1])
        }

        @Test(arguments: ["AXButton", "AXCell", "AXTextArea"])
        func `a window-sized element its role admits is kept`(role: String) {
            let elements = tree(Self.electron(groupFrame: windowFrame, role: role))
            #expect(Set(TargetRanker().rank(elements).map(\.elementIndex)) == [1, 3])
        }

        @Test
        func `the share is taken of the read's root, not of the screen's window`() {
            // A sheet read as the root: its own frame is what a group must cover.
            let elements = tree(
                Self.electron(groupFrame: rect(0, 0, 300, 200)),
                rootFrame: rect(0, 0, 400, 300),
                rootSubrole: "AXSheet",
            )
            #expect(TargetRanker().ranking(elements).exclusions[1] == .windowSizedGroup)
        }

        @Test
        func `nested window-sized groups are both dropped and what they hold is kept`() {
            let elements = tree([
                Spec(role: "AXGroup", frame: windowFrame, actions: ["AXPress"]),
                Spec(
                    role: "AXGroup",
                    frame: rect(0, 40, 900, 560),
                    actions: ["AXPress"],
                    parent: 1,
                ),
                Spec(frame: rect(100, 100, 40, 20), parent: 2),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.targets.map(\.elementIndex) == [3])
            #expect(ranking.exclusions[1] == .windowSizedGroup)
            #expect(ranking.exclusions[2] == .windowSizedGroup)
        }

        @Test
        func `a window-sized pressable row is dropped and its cells take its place`() {
            // The row is admitted only through AXPress, so it is a window-sized group; once
            // it is gone it is no target row, and its cells stay reachable.
            let elements = tree([
                Spec(role: "AXList", frame: windowFrame),
                Spec(role: "AXRow", frame: windowFrame, actions: ["AXPress"], parent: 1),
                Spec(role: "AXCell", frame: rect(0, 0, 450, 600), parent: 2),
                Spec(role: "AXCell", frame: rect(450, 0, 450, 600), parent: 2),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == .windowSizedGroup)
            #expect(Set(ranking.targets.map(\.elementIndex)) == [3, 4])
        }

        // MARK: - The ranking's report

        @Test
        func `the ranking reports the filter's reason for every other element`() {
            let elements = tree([
                Spec(role: "AXImage"),
                Spec(isEnabled: false),
                Spec(frame: nil),
                Spec(frame: rect(100, 100, 4, 4)),
                Spec(frame: rect(2_000, 100, 40, 20)),
                Spec(frame: rect(300, 300, 40, 20)),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions == [
                .notClickable, .notClickable, .disabled, .noFrame, .tooSmall, .outsideWindow, nil,
            ])
            #expect(ranking.targets.map(\.elementIndex) == [6])
        }

        @Test
        func `an empty read ranks nothing and reports nothing`() {
            let ranking = TargetRanker().ranking([])
            #expect(ranking.targets.isEmpty)
            #expect(ranking.exclusions.isEmpty)
        }
    }
}
