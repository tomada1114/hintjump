import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// One first-cut tier case: a tree, which of its elements is under test, and the tier it gets.
    struct TierCase: CustomTestStringConvertible {
        let name: String
        let specs: [Spec]
        let rootSubrole: String
        let expected: TargetTier

        var testDescription: String {
            name
        }

        init(_ name: String, _ specs: [Spec], expected: TargetTier) {
            self.init(name, specs, rootSubrole: "AXStandardWindow", expected: expected)
        }

        init(_ name: String, _ specs: [Spec], rootSubrole: String, expected: TargetTier) {
            self.name = name
            self.specs = specs
            self.rootSubrole = rootSubrole
            self.expected = expected
        }
    }

    @Suite("first-cut tiers")
    struct Tiers {
        /// A narrow outline flush with the window's leading edge, as Finder's sidebar is.
        private static let sidebar = Spec(role: "AXOutline", frame: rect(7, 50, 220, 540))
        /// A wide outline to the right of it, as Finder's list view is.
        private static let content = Spec(role: "AXOutline", frame: rect(230, 50, 660, 540))
        private static let toolbar = Spec(role: "AXToolbar", frame: rect(0, 0, 900, 50))

        static let cases: [TierCase] = [
            TierCase("a text field", [Spec(role: "AXTextField")], expected: .primary),
            TierCase("a text area", [Spec(role: "AXTextArea")], expected: .primary),
            TierCase("a search field role", [Spec(role: "AXSearchField")], expected: .primary),
            TierCase(
                "a text field with the search-field subrole",
                [Spec(role: "AXTextField", subrole: "AXSearchField")],
                expected: .primary,
            ),
            TierCase("an AXTab", [Spec(role: "AXTab")], expected: .primary),
            TierCase(
                "a tab button",
                [Spec(role: "AXRadioButton", subrole: "AXTabButton")],
                expected: .primary,
            ),
            TierCase(
                "a radio button in a tab group",
                [
                    Spec(role: "AXTabGroup", frame: windowFrame),
                    Spec(role: "AXRadioButton", parent: 1),
                ],
                expected: .primary,
            ),
            TierCase(
                "a button nested in a toolbar",
                [
                    toolbar,
                    Spec(role: "AXGroup", frame: rect(10, 5, 100, 40), parent: 1),
                    Spec(frame: rect(10, 5, 40, 40), parent: 2),
                ],
                expected: .primary,
            ),
            TierCase(
                "a menu button in a toolbar",
                [toolbar, Spec(role: "AXMenuButton", frame: rect(60, 5, 40, 40), parent: 1)],
                expected: .primary,
            ),
            TierCase(
                "a segment in a toolbar",
                [toolbar, Spec(role: "AXRadioButton", subrole: "AXSegment", parent: 1)],
                expected: .primary,
            ),
            TierCase(
                "a button in a sheet",
                [Spec(role: "AXSheet", frame: rect(200, 0, 400, 300)), Spec(parent: 1)],
                expected: .primary,
            ),
            TierCase("a button in a dialog", [Spec()], rootSubrole: "AXDialog", expected: .primary),
            TierCase(
                "a button in a system dialog",
                [Spec()],
                rootSubrole: "AXSystemDialog",
                expected: .primary,
            ),
            TierCase(
                "a sidebar row",
                [sidebar, Spec(role: "AXRow", frame: rect(7, 50, 220, 30), parent: 1)],
                expected: .primary,
            ),
            TierCase("a plain button", [Spec()], expected: .linkOrButton),
            TierCase("a link", [Spec(role: "AXLink")], expected: .linkOrButton),
            TierCase("a pop-up button", [Spec(role: "AXPopUpButton")], expected: .linkOrButton),
            TierCase("a menu button", [Spec(role: "AXMenuButton")], expected: .linkOrButton),
            TierCase(
                "a radio button outside a tab group",
                [
                    Spec(role: "AXRadioGroup", frame: rect(100, 100, 200, 40)),
                    Spec(role: "AXRadioButton", parent: 1),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a text field in a toolbar is still a text field",
                [toolbar, Spec(role: "AXTextField", frame: rect(700, 10, 180, 30), parent: 1)],
                expected: .primary,
            ),
            TierCase(
                "a content row",
                [content, Spec(role: "AXRow", frame: rect(230, 50, 660, 30), parent: 1)],
                expected: .rowOrCell,
            ),
            TierCase(
                "a row in an outline narrow enough but away from the leading edge",
                [
                    Spec(role: "AXOutline", frame: rect(400, 50, 200, 540)),
                    Spec(role: "AXRow", frame: rect(400, 50, 200, 30), parent: 1),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a row in an outline at the leading edge but too wide to be a sidebar",
                [
                    Spec(role: "AXTable", frame: rect(0, 50, 900, 540)),
                    Spec(role: "AXRow", frame: rect(0, 50, 900, 30), parent: 1),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a row whose outline reports no frame",
                [
                    Spec(role: "AXOutline", frame: nil),
                    Spec(role: "AXRow", frame: rect(7, 50, 220, 30), parent: 1),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a cell",
                [
                    content,
                    Spec(role: "AXRow", frame: rect(230, 50, 660, 30), parent: 1),
                    Spec(role: "AXCell", frame: rect(230, 50, 300, 30), parent: 2),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a text field inside a row is the row's label, not an input",
                [
                    content,
                    Spec(role: "AXRow", frame: rect(230, 50, 660, 30), parent: 1),
                    Spec(role: "AXCell", frame: rect(230, 50, 300, 30), parent: 2),
                    Spec(role: "AXTextField", frame: rect(260, 55, 100, 18), parent: 3),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a button inside a row stays a button",
                [
                    content,
                    Spec(role: "AXRow", frame: rect(230, 50, 660, 30), parent: 1),
                    Spec(frame: rect(850, 55, 20, 20), parent: 2),
                ],
                expected: .linkOrButton,
            ),
            TierCase("a checkbox", [Spec(role: "AXCheckBox")], expected: .other),
            TierCase("a slider", [Spec(role: "AXSlider")], expected: .other),
            TierCase("a combo box", [Spec(role: "AXComboBox")], expected: .other),
            TierCase(
                "a disclosure triangle",
                [Spec(role: "AXDisclosureTriangle")],
                expected: .other,
            ),
            TierCase(
                "static text with AXPress",
                [Spec(role: "AXStaticText", actions: ["AXPress"])],
                expected: .other,
            ),
        ]

        @Test(arguments: cases)
        func `each kind of element gets its first-cut tier`(of testCase: TierCase) throws {
            let elements = tree(
                testCase.specs,
                rootFrame: windowFrame,
                rootSubrole: testCase.rootSubrole,
            )
            let target = try #require(
                TargetRanker().rank(elements).first { $0.elementIndex == elements.count - 1 },
            )
            #expect(target.tier == testCase.expected)
        }

        @Test
        func `tiers order before position: tier 1 first even when it is last on screen`() {
            let elements = tree([
                Spec(role: "AXCheckBox", frame: rect(10, 10, 20, 20)),
                Spec(role: "AXCell", frame: rect(10, 40, 100, 20)),
                Spec(role: "AXLink", frame: rect(10, 70, 60, 20)),
                Spec(role: "AXTextField", frame: rect(10, 500, 200, 24)),
            ])
            let ranked = TargetRanker().rank(elements)
            #expect(ranked.map(\.elementIndex) == [4, 3, 2, 1])
            #expect(ranked.map(\.tier) == [.primary, .linkOrButton, .rowOrCell, .other])
            #expect(ranked.map(\.rank) == [1, 2, 3, 4])
        }

        @Test
        func `tiers compare by their number`() {
            #expect(TargetTier.allCases.sorted() == [.primary, .linkOrButton, .rowOrCell, .other])
            #expect(TargetTier.allCases.sorted().map(\.rawValue) == [1, 2, 3, 4])
        }
    }
}
