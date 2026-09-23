import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// The tier cases the target-count measurement added (`docs/research/target-counts.md`):
    /// a sidebar behind an icon rail, a pressable element standing in for its row, and the
    /// regions a web page marks with landmarks.
    @Suite("tiers by region")
    struct Regions {
        /// A page's web area, below a browser's tab bar and toolbar.
        private static let webArea = Spec(role: "AXWebArea", frame: rect(0, 90, 900, 510))

        static let sidebarCases: [TierCase] = [
            TierCase(
                "a row in an outline behind an icon rail, ending inside the leading third",
                [outline(from: 88, to: 288), row(parent: 1)],
                expected: .primary,
            ),
            TierCase(
                "a row in an outline ending exactly at the leading third",
                [outline(from: 100, to: 300), row(parent: 1)],
                expected: .primary,
            ),
            TierCase(
                "a row in an outline ending just past the leading third",
                [outline(from: 100, to: 301), row(parent: 1)],
                expected: .rowOrCell,
            ),
            TierCase(
                "a pressable row nested in a group inside a sidebar outline",
                [
                    Tiers.sidebar,
                    row(parent: 1),
                    group(parent: 2),
                    // Inset like its group: at the outer row's frame it would be a twin.
                    Spec(
                        role: "AXRow",
                        frame: rect(30, 60, 180, 28),
                        actions: ["AXPress"],
                        parent: 3,
                    ),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group directly inside a sidebar row that is not a target",
                [
                    Tiers.sidebar,
                    group(parent: 1),
                    row(parent: 2),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group two levels inside a sidebar row that is not a target",
                [
                    Tiers.sidebar, group(parent: 1), row(parent: 2), group(parent: 3),
                    group(parent: 4, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group three levels inside a sidebar row is not the row",
                [
                    Tiers.sidebar, group(parent: 1), row(parent: 2), group(parent: 3),
                    group(parent: 4),
                    group(parent: 5, actions: ["AXPress"]),
                ],
                expected: .other,
            ),
            TierCase(
                "a pressable group inside a sidebar row that is a target keeps its tier",
                [Tiers.sidebar, row(parent: 1), group(parent: 2, actions: ["AXPress"])],
                expected: .other,
            ),
            TierCase(
                "a pressable group inside a pressable sidebar row keeps its tier",
                [
                    Tiers.sidebar, group(parent: 1), row(parent: 2, actions: ["AXPress"]),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .other,
            ),
            TierCase(
                "a pressable group inside a disabled pressable sidebar row",
                [
                    Tiers.sidebar, group(parent: 1),
                    Spec(
                        role: "AXRow",
                        frame: rect(10, 60, 200, 28),
                        isEnabled: false,
                        actions: ["AXPress"],
                        parent: 2,
                    ),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group inside a pressable sidebar row too small to be a target",
                [
                    Tiers.sidebar, group(parent: 1),
                    Spec(
                        role: "AXRow",
                        frame: rect(10, 60, 200, 4),
                        actions: ["AXPress"],
                        parent: 2,
                    ),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group inside a pressable sidebar row centered outside the window",
                [
                    Tiers.sidebar, group(parent: 1),
                    Spec(
                        role: "AXRow",
                        frame: rect(10, 590, 200, 28),
                        actions: ["AXPress"],
                        parent: 2,
                    ),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group inside a disabled row directly in a sidebar outline",
                [
                    Tiers.sidebar,
                    Spec(role: "AXRow", frame: rect(10, 60, 200, 28), isEnabled: false, parent: 1),
                    group(parent: 2, actions: ["AXPress"]),
                ],
                expected: .primary,
            ),
            TierCase(
                "a pressable group inside a content row that is not a target keeps its tier",
                [
                    Tiers.content,
                    group(parent: 1),
                    row(parent: 2),
                    group(parent: 3, actions: ["AXPress"]),
                ],
                expected: .other,
            ),
            TierCase(
                "a pressable group inside a row with no outline above it keeps its tier",
                [row(parent: 0), group(parent: 1, actions: ["AXPress"])],
                expected: .other,
            ),
        ]

        static let webPageCases: [TierCase] = [
            TierCase(
                "a link in a page's main landmark",
                [webArea, landmark("AXLandmarkMain", parent: 1), Spec(role: "AXLink", parent: 2)],
                expected: .primary,
            ),
            TierCase(
                "a link in the main landmark but inside an iframe's web area",
                [
                    webArea, landmark("AXLandmarkMain", parent: 1),
                    Spec(role: "AXWebArea", frame: rect(600, 200, 280, 300), parent: 2),
                    Spec(role: "AXLink", frame: rect(600, 200, 280, 250), parent: 3),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a link in a main landmark outside any web area",
                [landmark("AXLandmarkMain", parent: 0), Spec(role: "AXLink", parent: 1)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a link in a page with no landmarks",
                [webArea, Spec(role: "AXLink", parent: 1)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a button in a page's main landmark stays a button",
                [webArea, landmark("AXLandmarkMain", parent: 1), Spec(parent: 2)],
                expected: .linkOrButton,
            ),
            TierCase(
                "a link in a page's navigation landmark",
                [
                    webArea, landmark("AXLandmarkNavigation", parent: 1),
                    Spec(role: "AXLink", parent: 2),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a link in a navigation landmark inside the main landmark",
                [
                    webArea, landmark("AXLandmarkMain", parent: 1),
                    landmark("AXLandmarkNavigation", parent: 2), Spec(role: "AXLink", parent: 3),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a text field in a page's banner is not an input the page is for",
                [
                    webArea, landmark("AXLandmarkBanner", parent: 1),
                    Spec(role: "AXTextField", frame: rect(600, 100, 200, 24), parent: 2),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a search field in a page's navigation",
                [
                    webArea, landmark("AXLandmarkNavigation", parent: 1),
                    Spec(role: "AXTextField", subrole: "AXSearchField", parent: 2),
                ],
                expected: .rowOrCell,
            ),
            TierCase(
                "a tab button in a page's banner is a plain button",
                [
                    webArea, landmark("AXLandmarkBanner", parent: 1),
                    Spec(role: "AXRadioButton", subrole: "AXTabButton", parent: 2),
                ],
                expected: .linkOrButton,
            ),
            TierCase(
                "a text field in a page's main landmark is still a text field",
                [
                    webArea, landmark("AXLandmarkMain", parent: 1),
                    Spec(role: "AXTextField", parent: 2),
                ],
                expected: .primary,
            ),
        ]

        /// A group carrying one of a page's landmark subroles, under the spec at `parent`.
        private static func landmark(_ subrole: String, parent: Int) -> Spec {
            Spec(role: "AXGroup", subrole: subrole, frame: rect(0, 90, 900, 510), parent: parent)
        }

        /// A plain container under the spec at `parent`, with `actions` (none by default).
        /// Inset in its row as VS Code's pressable group is, so a group and the row around
        /// it are never same-frame twins, of which only the first would be a target.
        private static func group(parent: Int, actions: [String] = []) -> Spec {
            Spec(role: "AXGroup", frame: rect(30, 60, 180, 28), actions: actions, parent: parent)
        }

        /// A row under the spec at `parent`, with `actions` (none by default).
        private static func row(parent: Int, actions: [String] = []) -> Spec {
            Spec(role: "AXRow", frame: rect(10, 60, 200, 28), actions: actions, parent: parent)
        }

        /// An outline from `left` to `right`, as a sidebar behind an icon rail would be.
        private static func outline(from left: CGFloat, to right: CGFloat) -> Spec {
            Spec(role: "AXOutline", frame: rect(left, 50, right - left, 540))
        }

        @Test(arguments: sidebarCases + webPageCases)
        func `each element gets the tier its region calls for`(of testCase: TierCase) throws {
            #expect(try tier(of: testCase) == testCase.expected)
        }
    }
}
