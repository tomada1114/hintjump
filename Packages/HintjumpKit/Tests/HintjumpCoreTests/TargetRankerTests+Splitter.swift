import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// Claude Desktop's sidebar as `just probe dump --rank` read it on 2026-09-23 at
    /// 5b294a5 (#115): the split view's "Resize sidebar" splitter reported `AXPress`,
    /// so it took a label on the invisible boundary between the sidebar and the
    /// transcript, and a splitter is only ever dragged.
    @Suite("a split view's splitter")
    struct Splitter {
        /// The main window, the read's root.
        private static let window = rect(1_280, 30, 1_280, 1_355)

        /// The sidebar's `AXLandmarkComplementary` group, the splitter's parent.
        private static let sidebar = rect(1_280, 30, 349, 1_355)

        /// The "Resize sidebar" splitter along the sidebar's right edge.
        private static let splitter = rect(1_619, 30, 18, 1_355)

        /// The sidebar's content group, which reports no `AXPress`.
        private static let sidebarContent = rect(1_280, 96, 348, 1_289)

        /// The "Daily Note" entry, its icon, its title group, and its "More options" pop-up.
        private static let entry = rect(1_291, 367, 325, 39)
        private static let entryIcon = rect(1_301, 376, 21, 21)
        private static let entryTitle = rect(1_334, 372, 279, 29)
        private static let moreOptions = rect(1_581, 371, 30, 30)

        private static func read() -> [ElementSnapshot] {
            let press = ["AXPress", "AXShowMenu"]
            return tree(
                [
                    Spec(
                        role: "AXGroup",
                        subrole: "AXLandmarkComplementary",
                        frame: sidebar,
                    ),
                    Spec(
                        role: "AXSplitter",
                        frame: splitter,
                        actions: ["AXPress", "AXShowMenu", "AXScrollToVisible"],
                        parent: 1,
                    ),
                    Spec(role: "AXGroup", frame: sidebarContent, parent: 1),
                    Spec(frame: entry, actions: press, parent: 3),
                    Spec(role: "AXImage", frame: entryIcon, actions: press, parent: 4),
                    Spec(role: "AXGroup", frame: entryTitle, actions: press, parent: 4),
                    Spec(role: "AXPopUpButton", frame: moreOptions, actions: press, parent: 3),
                ],
                rootFrame: window,
                rootSubrole: "AXStandardWindow",
            )
        }

        @Test
        func `the splitter is dropped as a splitter while the sidebar's buttons stay ranked`(
        ) throws {
            let elements = Self.read()
            let ranking = TargetRanker().ranking(elements)
            let index = try #require(elements.firstIndex { $0.frame == Self.splitter })
            #expect(ranking.exclusions[index] == .splitter)
            #expect(TargetRanker.exclusion(ofElementAt: index, in: elements) == .splitter)
            let frames = ranking.targets.map(\.element.frame)
            #expect(frames.contains(Self.entry))
            #expect(frames.contains(Self.moreOptions))
            #expect(!frames.contains(Self.splitter))
        }

        @Test
        func `a sidebar entry takes one label besides its More options pop-up`() throws {
            let elements = Self.read()
            let ranking = TargetRanker().ranking(elements)
            let frames = ranking.targets.map(\.element.frame)
            #expect(frames.count == 2)
            #expect(frames.contains(Self.entry))
            #expect(frames.contains(Self.moreOptions))
            for frame in [Self.entryIcon, Self.entryTitle] {
                let index = try #require(elements.firstIndex { $0.frame == frame })
                #expect(ranking.exclusions[index] == .insideTargetControl)
            }
        }
    }
}
