import CoreGraphics
import HintjumpCore
import Testing

extension TargetRankerTests {
    /// What is inside a button or link that is itself a target (#109): Chromium reports
    /// `AXPress` on nearly every element, so a Claude Desktop sidebar entry's icon and
    /// title group were admitted beside the entry's own button, and each entry took three
    /// labels for one destination.
    @Suite("content inside a button or link target")
    struct ControlContent {
        /// Claude Desktop's main window, as read on the owner's Mac.
        private static let claudeWindow = rect(1_175, 40, 1_400, 1_000)

        /// Electron's window-sized pressable group, and the web area inside it.
        private static let content = rect(1_175, 68, 1_400, 972)

        /// The sidebar's navigation group.
        private static let sidebar = rect(1_185, 100, 325, 900)

        /// The session entries of the sidebar, as the read placed the first of them: each
        /// its button, its icon, and the group holding its title.
        private static let entries = [328, 366, 404].map { (top: CGFloat) in
            (
                button: rect(1_185, top, 325, 38),
                icon: rect(1_195, top + 8, 21, 21),
                title: rect(1_228, top + 4, 279, 29),
            )
        }

        /// Claude Desktop's window with its sidebar of ``entries``: each an `AXButton`
        /// holding an `AXImage` and an `AXGroup` with the title's `AXStaticText`, all but
        /// the text reporting `AXPress` — or, unless `contentPressable`, only the button.
        /// The second entry's title group carries the `AXApplicationStatus` subrole, as
        /// one did in the read.
        private static func claudeSidebar(contentPressable: Bool = true) -> [Spec] {
            let press = ["AXPress", "AXShowMenu"]
            var specs = [
                Spec(role: "AXGroup", frame: content, actions: ["AXPress"]),
                Spec(role: "AXWebArea", frame: content, parent: 1),
                Spec(role: "AXGroup", frame: sidebar, actions: press, parent: 2),
            ]
            for (offset, entry) in entries.enumerated() {
                let button = specs.count + 1
                specs.append(Spec(frame: entry.button, actions: press, parent: 3))
                specs.append(Spec(
                    role: "AXImage",
                    frame: entry.icon,
                    actions: contentPressable ? press : [],
                    parent: button,
                ))
                specs.append(Spec(
                    role: "AXGroup",
                    subrole: offset == 1 ? "AXApplicationStatus" : nil,
                    frame: entry.title,
                    actions: contentPressable ? press : [],
                    parent: button,
                ))
                specs.append(Spec(
                    role: "AXStaticText",
                    frame: entry.title.insetBy(dx: 2, dy: 6),
                    parent: button + 2,
                ))
            }
            return specs
        }

        private static func read(_ specs: [Spec]) -> [ElementSnapshot] {
            tree(specs, rootFrame: claudeWindow, rootSubrole: "AXStandardWindow")
        }

        /// A window holding a `control` target with a pressable group inside it, which
        /// is the last element.
        private static func pressableGroup(
            in control: Spec,
            between middle: [Spec] = [],
        ) -> [ElementSnapshot] {
            var specs = [control]
            for spec in middle {
                var nested = spec
                nested.parent = specs.count
                specs.append(nested)
            }
            specs.append(Spec(
                role: "AXGroup",
                frame: rect(104, 102, 20, 16),
                actions: ["AXPress"],
                parent: specs.count,
            ))
            return tree(specs)
        }

        // MARK: - Claude Desktop's sidebar

        @Test
        func `a sidebar entry's icon and title group are dropped as inside the entry`() throws {
            let elements = Self.read(Self.claudeSidebar())
            let ranking = TargetRanker().ranking(elements)
            for entry in Self.entries {
                for frame in [entry.icon, entry.title] {
                    let index = try #require(elements.firstIndex { $0.frame == frame })
                    #expect(ranking.exclusions[index] == .insideTargetControl)
                }
            }
            let buttons = Self.entries.map(\.button)
            let frames = ranking.targets.map(\.element.frame)
            #expect(frames.filter { $0 != Self.sidebar } == buttons)
        }

        @Test
        func `the sidebar entries keep their ranks and tiers`() {
            let pressable = TargetRanker().ranking(Self.read(Self.claudeSidebar()))
            let plain = TargetRanker().ranking(Self.read(Self.claudeSidebar(
                contentPressable: false,
            )))
            #expect(pressable.targets.map(\.element.frame) == plain.targets.map(\.element.frame))
            #expect(pressable.targets.map(\.rank) == plain.targets.map(\.rank))
            #expect(pressable.targets.map(\.tier) == plain.targets.map(\.tier))
        }

        @Test
        func `the title's static text is still turned away by the filter`() throws {
            let elements = Self.read(Self.claudeSidebar())
            let text = try #require(elements.firstIndex { $0.role == "AXStaticText" })
            #expect(TargetRanker().ranking(elements).exclusions[text] == .notClickable)
        }

        // MARK: - Which controls own their content

        @Test(arguments: ["AXButton", "AXLink"])
        func `a pressable group inside a button or link target is dropped`(role: String) {
            let elements = Self.pressableGroup(in: Spec(role: role, frame: rect(100, 100, 40, 20)))
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == .insideTargetControl)
            #expect(ranking.targets.map(\.elementIndex) == [1])
        }

        @Test
        func `pressable content nested in pressable content is dropped with it`() {
            let outer = Spec(role: "AXGroup", frame: rect(102, 101, 30, 18), actions: ["AXPress"])
            let elements = Self.pressableGroup(
                in: Spec(role: "AXLink", frame: rect(100, 100, 40, 20)),
                between: [outer],
            )
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == .insideTargetControl)
            #expect(ranking.exclusions[3] == .insideTargetControl)
            #expect(ranking.targets.map(\.elementIndex) == [1])
        }

        @Test(arguments: [
            "AXCheckBox", "AXPopUpButton", "AXMenuButton", "AXButton", "AXLink", "AXTextField",
        ])
        func `a control clickable by role inside a button is kept`(role: String) {
            let elements = tree([
                Spec(frame: rect(100, 100, 200, 40)),
                Spec(role: role, frame: rect(110, 110, 20, 20), parent: 1),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == nil)
            #expect(Set(ranking.targets.map(\.elementIndex)) == [1, 2])
        }

        @Test(arguments: [
            Spec(role: "AXCheckBox", frame: rect(102, 101, 30, 18)),
            Spec(role: "AXPopUpButton", frame: rect(102, 101, 30, 18)),
            Spec(role: "AXMenuButton", frame: rect(102, 101, 30, 18)),
            // A row in no outline or table, not clickable by role: still another rule's.
            Spec(role: "AXRow", frame: rect(102, 101, 30, 18)),
        ])
        func `content of a control nested in the button is left to that control`(
            middle: Spec,
        ) {
            let elements = Self.pressableGroup(
                in: Spec(frame: rect(100, 100, 40, 20)),
                between: [middle],
            )
            #expect(TargetRanker().ranking(elements).exclusions[3] == nil)
        }

        @Test
        func `a pressable group outside any button or link is kept`() {
            let elements = Self.pressableGroup(
                in: Spec(role: "AXGroup", frame: rect(100, 100, 40, 20), actions: ["AXPress"]),
            )
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == nil)
            #expect(Set(ranking.targets.map(\.elementIndex)) == [1, 2])
        }

        // MARK: - A button that is no target

        @Test(
            arguments: [
                (Spec(frame: rect(100, 100, 40, 20), isEnabled: false), TargetExclusion.disabled),
                (Spec(frame: nil), .noFrame),
                (Spec(frame: rect(100, 100, 6, 20)), .tooSmall),
                (Spec(frame: rect(1_000, 100, 40, 20)), .outsideWindow),
            ] as [(Spec, TargetExclusion)],
        )
        func `a pressable group whose button is itself excluded is kept`(
            button: Spec,
            reason: TargetExclusion,
        ) {
            let elements = Self.pressableGroup(in: button)
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[1] == reason)
            #expect(ranking.exclusions[2] == nil)
            #expect(ranking.targets.map(\.elementIndex) == [2])
        }

        @Test
        func `a window-sized pressable group is still reported as window-sized`() {
            // It covers the whole window and holds the button, so the earlier rule wins,
            // even though it sits inside a link.
            let elements = tree([
                Spec(role: "AXLink", frame: windowFrame),
                Spec(role: "AXGroup", frame: windowFrame, actions: ["AXPress"], parent: 1),
                Spec(frame: rect(100, 100, 40, 20), parent: 2),
            ])
            let ranking = TargetRanker().ranking(elements)
            #expect(ranking.exclusions[2] == .windowSizedGroup)
        }
    }
}
