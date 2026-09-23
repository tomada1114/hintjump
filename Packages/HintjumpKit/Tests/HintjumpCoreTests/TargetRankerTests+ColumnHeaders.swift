import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// A row the column header hides (#98): Finder's list view reads an outline row
    /// entirely behind the header's sort buttons, and a click at its visible center
    /// re-sorts the list instead of selecting anything.
    @Suite("rows under a column header")
    struct ColumnHeaders {
        /// A Finder window with its list view, as read on the owner's Mac.
        private static let finderWindow = rect(0, 206, 1_200, 1_060)

        /// The outline's frame, and the scroll area's around it.
        private static let outlineFrame = rect(268, 258, 923, 995)

        /// The row hidden behind the header: one full-width cell, no text field.
        private static let hiddenRow = rect(269, 264, 921, 28)

        /// The first two rows the list view shows, below the header.
        private static let visibleRows = [rect(269, 292, 921, 36), rect(269, 328, 921, 36)]

        /// The header group — zero height, as Finder reports it — and its sort buttons.
        private static let headerGroup = rect(269, 259, 921, 0)
        private static let sortButtons = [
            rect(279, 259, 525, 28), rect(804, 259, 158, 28),
            rect(962, 259, 97, 28), rect(1_059, 259, 121, 28),
        ]

        /// A window holding a scroll area with one `container` in it: `rows`, each a row
        /// with one full-width cell, and a header of `header` buttons placed at
        /// `placement` unless `header` is empty — read after the rows, as Finder reports
        /// it, unless `headerFirst`.
        private static func listView(
            rows: [CGRect],
            container: String = "AXOutline",
            header: [ColumnHeaderButton] = sortButtons.map { ColumnHeaderButton(frame: $0) },
            placement: ColumnHeaderPlacement = .inHeaderGroup,
            headerFirst: Bool = false,
        ) -> [Spec] {
            var specs = [
                Spec(role: "AXScrollArea", frame: outlineFrame),
                Spec(role: container, frame: outlineFrame, actions: ["AXShowMenu"], parent: 1),
            ]
            let outline = 2
            let appendRows = {
                for frame in rows {
                    specs.append(Spec(
                        role: "AXRow",
                        subrole: "AXOutlineRow",
                        frame: frame,
                        actions: ["AXShowDefaultUI", "AXShowAlternateUI"],
                        parent: outline,
                    ))
                    specs.append(Spec(role: "AXCell", frame: frame, parent: specs.count))
                }
            }
            let appendHeader = {
                guard !header.isEmpty else {
                    return
                }
                var parent = outline
                for _ in 0 ..< placement.rawValue {
                    specs.append(Spec(role: "AXGroup", frame: headerGroup, parent: parent))
                    parent = specs.count
                }
                for button in header {
                    specs.append(Spec(
                        role: button.role,
                        subrole: button.subrole,
                        frame: button.frame,
                        isEnabled: button.isEnabled,
                        actions: ["AXPress"],
                        parent: parent,
                    ))
                }
            }
            if headerFirst {
                appendHeader()
                appendRows()
            } else {
                appendRows()
                appendHeader()
            }
            return specs
        }

        private static func read(
            _ specs: [Spec],
            root: CGRect = finderWindow,
        ) -> [ElementSnapshot] {
            tree(specs, rootFrame: root, rootSubrole: "AXStandardWindow")
        }

        /// The index of the row with `frame` in `elements`.
        private static func row(_ frame: CGRect, in elements: [ElementSnapshot]) throws -> Int {
            try #require(elements.firstIndex { $0.role == "AXRow" && $0.frame == frame })
        }

        // MARK: - Finder's list view

        @Test(arguments: [false, true])
        func `a row whose visible center lies under a sort button is dropped`(
            headerFirst: Bool,
        ) throws {
            let elements = Self.read(Self.listView(
                rows: [Self.hiddenRow] + Self.visibleRows,
                headerFirst: headerFirst,
            ))
            let ranking = TargetRanker().ranking(elements)
            let hidden = try Self.row(Self.hiddenRow, in: elements)
            #expect(ranking.exclusions[hidden] == .underColumnHeader)
            // Its cell shares its hidden spot and goes with it rather than standing in.
            #expect(ranking.exclusions[hidden + 1] == .insideTargetRow)
            #expect(!ranking.targets.contains { $0.element.frame == Self.hiddenRow })
        }

        @Test
        func `the rows below the header and the sort buttons keep their ranks and tiers`() {
            let withHidden = TargetRanker().ranking(Self.read(Self.listView(
                rows: [Self.hiddenRow] + Self.visibleRows,
            )))
            let withoutHidden = TargetRanker().ranking(Self.read(Self.listView(
                rows: Self.visibleRows,
            )))
            #expect(withHidden.targets.map(\.element.frame) == withoutHidden.targets
                .map(\.element.frame))
            #expect(withHidden.targets.map(\.tier) == withoutHidden.targets.map(\.tier))
            #expect(withHidden.targets.map(\.rank) == withoutHidden.targets.map(\.rank))
            #expect(withHidden.targets.map(\.element.frame) == Self.sortButtons + Self.visibleRows)
            #expect(withHidden.targets.map(\.tier) == [
                .linkOrButton, .linkOrButton, .linkOrButton, .linkOrButton, .rowOrCell, .rowOrCell,
            ])
        }

        @Test(arguments: ["AXOutline", "AXTable"])
        func `an outline or table with no header keeps its first row`(container: String) throws {
            let elements = Self.read(Self.listView(
                rows: [Self.hiddenRow] + Self.visibleRows,
                container: container,
                header: [],
            ))
            let ranking = TargetRanker().ranking(elements)
            let first = try Self.row(Self.hiddenRow, in: elements)
            #expect(ranking.exclusions[first] == nil)
            #expect(ranking.targets.map(\.element.frame) == [Self.hiddenRow] + Self.visibleRows)
        }

        @Test
        func `a table's row under its column header is dropped like an outline's`() throws {
            let elements = Self.read(Self.listView(rows: [Self.hiddenRow], container: "AXTable"))
            let hidden = try Self.row(Self.hiddenRow, in: elements)
            #expect(TargetRanker().ranking(elements).exclusions[hidden] == .underColumnHeader)
        }

        // MARK: - Where the center falls

        @Test(
            arguments: [
                // Its top edge under the header, its center 3 pt below the buttons' 287.
                (rect(269, 270, 921, 40), nil),
                // Its center exactly on the buttons' bottom edge, the first point below them.
                (rect(269, 277, 921, 20), nil),
                // Its center half a point above that edge.
                (rect(269, 276, 921, 21), .underColumnHeader),
                // Its center in the gap left of the first sort button, under no button.
                (rect(269, 264, 10, 28), nil),
            ] as [(CGRect, TargetExclusion?)],
        )
        func `a row is dropped only when its center lies inside a header button`(
            rowFrame: CGRect,
            expected: TargetExclusion?,
        ) throws {
            let elements = Self.read(Self.listView(rows: [rowFrame] + Self.visibleRows))
            let row = try Self.row(rowFrame, in: elements)
            #expect(TargetRanker().ranking(elements).exclusions[row] == expected)
        }

        @Test
        func `the center tested is the visible one the click lands on`() throws {
            // The window's top edge cuts the row: its own center, y 250, is above the
            // header, but its visible part spans 250–300 and is clicked at y 275.
            let rowFrame = rect(269, 200, 921, 100)
            let elements = Self.read(
                Self.listView(rows: [rowFrame]),
                root: rect(0, 250, 1_200, 1_016),
            )
            let row = try Self.row(rowFrame, in: elements)
            #expect(TargetRanker().ranking(elements).exclusions[row] == .underColumnHeader)
        }

        // MARK: - What counts as a column-header button

        @Test(
            arguments: [
                // Finder's sort button in its header group.
                (ColumnHeaderButton(frame: sortButtons[0]), true),
                // A disabled one still covers the row; the click lands on it all the same.
                (ColumnHeaderButton(frame: sortButtons[0], isEnabled: false), true),
                // A sort button anywhere under the outline.
                (ColumnHeaderButton(frame: sortButtons[0], placement: .nestedTwoGroupsDeep), true),
                (ColumnHeaderButton(frame: sortButtons[0], placement: .directlyInContainer), true),
                // A plain button in the header group: a column that does not sort.
                (ColumnHeaderButton(subrole: nil, frame: sortButtons[0]), true),
                // A plain button anywhere else under the outline is no column header.
                (
                    ColumnHeaderButton(
                        subrole: nil,
                        frame: sortButtons[0],
                        placement: .nestedTwoGroupsDeep,
                    ),
                    false,
                ),
                (
                    ColumnHeaderButton(
                        subrole: nil,
                        frame: sortButtons[0],
                        placement: .directlyInContainer,
                    ),
                    false,
                ),
                // Something other than a button in the header group.
                (
                    ColumnHeaderButton(role: "AXStaticText", subrole: nil, frame: sortButtons[0]),
                    false,
                ),
            ] as [(ColumnHeaderButton, Bool)],
        )
        func `a column-header button is a sort button, or a button in the header group`(
            button: ColumnHeaderButton,
            hidesRow: Bool,
        ) throws {
            let elements = Self.read(Self.listView(
                rows: [Self.hiddenRow],
                header: [button],
                placement: button.placement,
            ))
            let hidden = try Self.row(Self.hiddenRow, in: elements)
            let exclusion = TargetRanker().ranking(elements).exclusions[hidden]
            #expect(exclusion == (hidesRow ? .underColumnHeader : nil))
        }

        @Test
        func `another outline's header does not hide a row`() throws {
            // Two outlines side by side in one window, the second's header drawn over the
            // first's row: geometry alone would drop it, but the header is not its own.
            var specs = Self.listView(rows: [Self.hiddenRow], header: [])
            let other = specs.count + 1
            specs.append(Spec(role: "AXOutline", frame: Self.outlineFrame))
            specs.append(Spec(role: "AXGroup", frame: Self.headerGroup, parent: other))
            specs.append(Spec(
                role: "AXButton",
                subrole: "AXSortButton",
                frame: Self.sortButtons[0],
                actions: ["AXPress"],
                parent: other + 1,
            ))
            let elements = Self.read(specs)
            let row = try Self.row(Self.hiddenRow, in: elements)
            #expect(TargetRanker().ranking(elements).exclusions[row] == nil)
        }

        @Test
        func `a row already dropped keeps its first reason`() {
            // Disabled rows are turned away by the filter before any header is consulted.
            var specs = Self.listView(rows: [Self.hiddenRow])
            specs[2].isEnabled = false
            let elements = Self.read(specs)
            #expect(TargetRanker().ranking(elements).exclusions[3] == .disabled)
        }
    }
}

extension TargetRankerTests {
    /// Where a column-header button sits in the tree: how many groups stand between it and
    /// its outline or table.
    enum ColumnHeaderPlacement: Int {
        /// Directly in the outline, with no group around it.
        case directlyInContainer = 0
        /// In a group directly in the outline — Finder's shape.
        case inHeaderGroup = 1
        /// In a group inside a group inside the outline.
        case nestedTwoGroupsDeep = 2
    }

    /// One column-header button as the tree carries it, and where it sits.
    struct ColumnHeaderButton {
        var role = "AXButton"
        var subrole: String? = "AXSortButton"
        var frame: CGRect
        var isEnabled = true
        var placement = ColumnHeaderPlacement.inHeaderGroup
    }
}
