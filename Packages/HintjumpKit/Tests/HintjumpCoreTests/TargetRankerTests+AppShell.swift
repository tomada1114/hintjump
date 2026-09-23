import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// A web app shell's sidebar (#110): an Electron window whose web area fills the
    /// window, holding an `AXLandmarkComplementary` group in its leading third, as Claude
    /// Desktop's sessions and settings are. Its entries are buttons and pop-ups in plain
    /// groups, with no outline and no rows, so the sidebar row test does not see them.
    @Suite("an app shell's sidebar")
    struct AppShell {
        /// A web area filling ``windowFrame``, as an Electron app's does.
        private static let shell = Spec(role: "AXWebArea", frame: windowFrame)
        /// A page's web area, below a browser's tab bar and toolbar.
        private static let page = Spec(role: "AXWebArea", frame: rect(0, 90, 900, 510))
        /// A 260 pt sidebar flush with the leading edge, under the web area at index 1.
        private static let sidebar = complementary(from: 0, to: 260, parent: 1)

        static let entryCases: [TierCase] = [
            TierCase(
                "a full-width button in the sidebar",
                [shell, sidebar, entry(width: 240)],
                expected: .primary,
            ),
            TierCase(
                "a full-width link in the sidebar",
                [shell, sidebar, entry(width: 240, role: "AXLink")],
                expected: .primary,
            ),
            TierCase(
                "a pop-up exactly half the sidebar's width",
                [shell, sidebar, entry(width: 130, role: "AXPopUpButton")],
                expected: .primary,
            ),
            TierCase(
                "a pop-up just under half the sidebar's width",
                [shell, sidebar, entry(width: 129, role: "AXPopUpButton")],
                expected: .linkOrButton,
            ),
            TierCase(
                "an entry's 30 pt \"…\" pop-up",
                [shell, sidebar, entry(width: 30, role: "AXPopUpButton", left: 220)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a top icon button in the sidebar",
                [shell, sidebar, Spec(frame: rect(120, 17, 36, 35), parent: 2)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a full-width radio button in the sidebar is not an entry role",
                [shell, sidebar, entry(width: 240, role: "AXRadioButton")],
                expected: .linkOrButton,
            ),
            TierCase(
                "a full-width button measured against its nearest complementary landmark",
                [
                    shell, sidebar, complementary(from: 0, to: 100, parent: 2),
                    entry(width: 60, parent: 3),
                ],
                expected: .primary,
            ),
            TierCase(
                "a full-width button in a navigation landmark inside the sidebar",
                [
                    shell, sidebar,
                    Spec(
                        role: "AXGroup",
                        subrole: "AXLandmarkNavigation",
                        frame: rect(0, 90, 260, 400),
                        parent: 2,
                    ),
                    entry(width: 240, parent: 3),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a window's close button in the sidebar still ranks last",
                [
                    shell,
                    sidebar,
                    Spec(subrole: "AXCloseButton", frame: rect(5, 5, 240, 30), parent: 2),
                ],
                expected: .other,
            ),
        ]

        static let placementCases: [TierCase] = [
            TierCase(
                "a browser page's aside, below the window's top",
                [page, sidebar, entry(width: 240)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a web area 1 pt below the window's top is still an app shell",
                [Spec(role: "AXWebArea", frame: rect(0, 1, 900, 599)), sidebar, entry(width: 240)],
                expected: .primary,
            ),
            TierCase(
                "a web area 1.5 pt below the window's top is not an app shell",
                [
                    Spec(role: "AXWebArea", frame: rect(0, 1.5, 900, 598.5)), sidebar,
                    entry(width: 240),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a web area narrower than the window is not an app shell",
                [Spec(role: "AXWebArea", frame: rect(0, 0, 600, 600)), sidebar, entry(width: 240)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a web area starting past the window's leading edge is not an app shell",
                [Spec(role: "AXWebArea", frame: rect(2, 0, 898, 600)), sidebar, entry(width: 240)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a sidebar in an iframe inside an app shell",
                [
                    shell,
                    Spec(role: "AXWebArea", frame: rect(0, 90, 900, 510), parent: 1),
                    complementary(from: 0, to: 260, parent: 2),
                    entry(width: 240, parent: 3),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a sidebar with no web area above it",
                [complementary(from: 0, to: 260, parent: 0), entry(width: 240, parent: 1)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a sidebar ending exactly at the leading third",
                [shell, complementary(from: 0, to: 300, parent: 1), entry(width: 240)],
                expected: .primary,
            ),
            TierCase(
                "a complementary landmark ending just past the leading third",
                [shell, complementary(from: 0, to: 301, parent: 1), entry(width: 240)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a complementary landmark on the trailing side",
                [shell, complementary(from: 640, to: 900, parent: 1), entry(width: 240, left: 650)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a complementary landmark with no frame",
                [
                    shell,
                    Spec(
                        role: "AXGroup",
                        subrole: "AXLandmarkComplementary",
                        frame: nil,
                        parent: 1,
                    ),
                    entry(width: 240),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "an app shell's web area with no frame",
                [Spec(role: "AXWebArea", frame: nil), sidebar, entry(width: 240)],
                expected: .linkOrButton,
            ),
        ]

        /// Claude Desktop's main window as read on 2026-09-23 (#110), with the window's
        /// own frame; the top bar's radio buttons and the main pane's controls are placed
        /// approximately, since the read gave only their sizes.
        private static let claudeWindow = rect(1_174, 30, 1_386, 1_355)
        private static let claudeDesktop: [Spec] = [
            Spec(role: "AXWebArea", frame: claudeWindow),
            Spec(
                role: "AXGroup",
                subrole: "AXLandmarkComplementary",
                frame: rect(1_174, 30, 349, 1_355),
                parent: 1,
            ),
            Spec(frame: rect(1_294, 47, 36, 35), parent: 2),
            Spec(frame: rect(1_329, 47, 36, 35), parent: 2),
            Spec(role: "AXRadioGroup", frame: rect(1_380, 45, 100, 39), parent: 2),
            Spec(role: "AXRadioButton", frame: rect(1_380, 45, 50, 39), parent: 5),
            Spec(role: "AXRadioButton", frame: rect(1_430, 45, 50, 39), parent: 5),
            Spec(frame: rect(1_185, 107, 325, 39), parent: 2),
            Spec(frame: rect(1_185, 145, 325, 39), parent: 2),
            Spec(role: "AXPopUpButton", frame: rect(1_475, 150, 30, 30), parent: 2),
            Spec(frame: rect(1_185, 184, 325, 38), parent: 2),
            Spec(role: "AXPopUpButton", frame: rect(1_185, 222, 325, 38), parent: 2),
            Spec(frame: rect(1_188, 290, 245, 36), parent: 2),
            Spec(frame: rect(1_438, 290, 36, 36), parent: 2),
            Spec(frame: rect(1_185, 328, 325, 38), parent: 2),
            Spec(role: "AXPopUpButton", frame: rect(1_475, 332, 30, 30), parent: 2),
            Spec(frame: rect(1_185, 367, 325, 38), parent: 2),
            Spec(frame: rect(1_185, 407, 325, 38), parent: 2),
            Spec(frame: rect(1_185, 446, 325, 38), parent: 2),
            Spec(frame: rect(1_188, 512, 280, 35), parent: 2),
            Spec(role: "AXPopUpButton", frame: rect(1_185, 1_333, 216, 41), parent: 2),
            Spec(frame: rect(1_475, 1_336, 35, 35), parent: 2),
            Spec(role: "AXGroup", frame: rect(1_523, 30, 1_037, 60), parent: 1),
            Spec(frame: rect(1_700, 45, 240, 30), parent: 23),
            Spec(role: "AXPopUpButton", frame: rect(2_200, 45, 140, 30), parent: 23),
            Spec(role: "AXPopUpButton", frame: rect(2_350, 45, 140, 30), parent: 23),
            Spec(
                role: "AXGroup",
                subrole: "AXLandmarkMain",
                frame: rect(1_523, 90, 1_037, 1_295),
                parent: 1,
            ),
            Spec(role: "AXLink", frame: rect(1_600, 400, 300, 20), parent: 27),
            Spec(role: "AXLink", frame: rect(1_600, 700, 300, 20), parent: 27),
            Spec(role: "AXTextArea", frame: rect(1_598, 1_291, 849, 30), parent: 27),
        ]

        /// An `AXLandmarkComplementary` group from `left` to `right`, the window's height,
        /// under the spec at `parent`.
        private static func complementary(
            from left: CGFloat,
            to right: CGFloat,
            parent: Int,
        ) -> Spec {
            Spec(
                role: "AXGroup",
                subrole: "AXLandmarkComplementary",
                frame: rect(left, 0, right - left, 600),
                parent: parent,
            )
        }

        /// A sidebar entry of `role` and `width` at `left`, under the spec at `parent` —
        /// the sidebar, index 2, by default.
        private static func entry(
            width: CGFloat,
            role: String = "AXButton",
            left: CGFloat = 10,
            parent: Int = 2,
        ) -> Spec {
            Spec(role: role, frame: rect(left, 100, width, 38), parent: parent)
        }

        @Test(arguments: entryCases + placementCases)
        func `each element gets the tier its place in the shell calls for`(
            of testCase: TierCase,
        ) throws {
            #expect(try tier(of: testCase) == testCase.expected)
        }

        @Test
        func `in Claude Desktop, the sessions and the settings pop-up take singles ahead of the top bar`() {
            let elements = tree(
                Self.claudeDesktop,
                rootFrame: Self.claudeWindow,
                rootSubrole: "AXStandardWindow",
            )
            let ranked = TargetRanker().rank(elements)
            let rank = { (index: Int) in ranked.first { $0.elementIndex == index }?.rank ?? .max }
            let sidebarEntries = [8, 9, 11, 12, 13, 15, 17, 18, 19, 20, 21]
            let sessions = [15, 17, 18, 19]
            let settings = 21
            let topBar = [3, 4, 6, 7, 24, 25, 26]
            // The three existing primaries — the transcript's links and the composer —
            // and the eleven sidebar entries, all within the 16 singles.
            let primaries = Set(sidebarEntries + [28, 29, 30])
            #expect(Set(ranked.prefix(primaries.count).map(\.elementIndex)) == primaries)
            #expect(ranked.prefix(primaries.count).allSatisfy { $0.tier == .primary })
            #expect((sessions + [settings]).allSatisfy { rank($0) <= 16 })
            let lastEntry = sidebarEntries.map(rank).max() ?? .max
            #expect(topBar.allSatisfy { rank($0) > lastEntry && rank($0) != .max })
            // Each entry's "…" pop-up, the icon beside the recents header, and the one
            // beside the settings pop-up stay plain buttons.
            #expect([10, 14, 16, 22].allSatisfy { index in
                ranked.first { $0.elementIndex == index }?.tier == .linkOrButton
            })
        }
    }
}
