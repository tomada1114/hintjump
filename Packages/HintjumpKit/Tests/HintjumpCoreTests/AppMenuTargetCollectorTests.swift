import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// Reading the frontmost app's menu bar and turning its titles into hint targets,
/// against `FakeAccessibilityTreeReader`.
@MainActor
@Suite("AppMenuTargetCollector")
struct AppMenuTargetCollectorTests {
    static let pid: pid_t = 4_343
    static let app = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: pid,
    )
    static let barFrame = CGRect(x: 0, y: 0, width: 1_440, height: 24)
    static let apple = CGRect(x: 10, y: 0, width: 34, height: 24)
    static let finder = CGRect(x: 44, y: 0, width: 58, height: 24)
    static let file = CGRect(x: 102, y: 0, width: 38, height: 24)
    static let edit = CGRect(x: 140, y: 0, width: 38, height: 24)

    /// An element under the bar (or under `parent`), enabled unless told otherwise.
    private static func element(
        role: String,
        frame: CGRect?,
        parent: Int = 0,
        isEnabled: Bool = true,
    ) -> ElementSnapshot {
        ElementSnapshot(
            role: role,
            subrole: nil,
            title: "Private title",
            description: nil,
            frame: frame,
            isEnabled: isEnabled,
            actions: ["AXPress", "AXCancel"],
            depth: parent + 1,
            parentIndex: parent,
        )
    }

    /// A `.menuBar` snapshot whose root is a bar at `barFrame`, followed by `children`.
    private static func snapshot(
        children: [ElementSnapshot],
        barFrame: CGRect? = barFrame,
    ) -> TreeSnapshot {
        let bar = ElementSnapshot(
            role: "AXMenuBar",
            subrole: nil,
            title: nil,
            description: nil,
            frame: barFrame,
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        return TreeSnapshot(
            bundleIdentifier: "com.apple.finder",
            pid: pid,
            scope: .menuBar,
            strategy: .batched,
            elements: [bar] + children,
            readDuration: .milliseconds(3),
        )
    }

    /// The target a title at `frame` becomes: clicked at its center.
    private static func target(_ frame: CGRect) -> HintTarget {
        HintTarget(
            frame: frame,
            clickPoint: CGPoint(x: frame.midX, y: frame.midY),
            role: "AXMenuBarItem",
        )
    }

    @Test
    func `reads only the menu bar's titles, batched, one level deep`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.snapshot(children: [])])
        let collector = AppMenuTargetCollector(reader: reader)

        _ = try collector.collect(from: Self.app)

        #expect(reader.readRequests == [
            .init(pid: Self.pid, scope: .menuBar, strategy: .batched, maxDepth: 1),
        ])
    }

    @Test
    func `every enabled title is a target, in the order the bar reports them`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(children: [
                Self.element(role: "AXMenuBarItem", frame: Self.apple),
                Self.element(role: "AXMenuBarItem", frame: Self.finder),
                Self.element(role: "AXMenuBarItem", frame: Self.file),
                Self.element(role: "AXMenuBarItem", frame: Self.edit),
            ]),
        ])
        let collector = AppMenuTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set == TargetSet(
            pid: Self.pid,
            bundleIdentifier: "com.apple.finder",
            rootFrame: Self.barFrame,
            targets: [Self.apple, Self.finder, Self.file, Self.edit].map(Self.target),
            readDuration: .milliseconds(3),
        ))
    }

    @Test
    func `drops what is not a title of this bar, disabled, or a sliver`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(children: [
                // 1: kept.
                Self.element(role: "AXMenuBarItem", frame: Self.file),
                // 2: a menu under File, as a read that ignored the depth limit would give.
                Self.element(
                    role: "AXMenu",
                    frame: CGRect(x: 102, y: 24, width: 200, height: 300),
                    parent: 1,
                ),
                // 3: a title-shaped element two levels down.
                Self.element(role: "AXMenuBarItem", frame: Self.edit, parent: 2),
                // 4: a direct child of the bar that is not a title.
                Self.element(role: "AXGroup", frame: Self.edit),
                // 5: a disabled title.
                Self.element(role: "AXMenuBarItem", frame: Self.edit, isEnabled: false),
                // 6–8: slivers, exactly at the 2 pt bound either way, and no frame at all.
                Self.element(
                    role: "AXMenuBarItem",
                    frame: CGRect(x: 200, y: 0, width: 2, height: 24),
                ),
                Self.element(
                    role: "AXMenuBarItem",
                    frame: CGRect(x: 210, y: 0, width: 30, height: 2),
                ),
                Self.element(role: "AXMenuBarItem", frame: nil),
                // 9: just past the bound, so kept.
                Self.element(
                    role: "AXMenuBarItem",
                    frame: CGRect(x: 250, y: 0, width: 3, height: 3),
                ),
            ]),
        ])
        let collector = AppMenuTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set.targets == [
            Self.target(Self.file),
            Self.target(CGRect(x: 250, y: 0, width: 3, height: 3)),
        ])
    }

    @Test
    func `a title hanging off the bar is clicked at the center of its visible part`() throws {
        let overhanging = CGRect(x: 1_420, y: 0, width: 40, height: 24)
        let outside = CGRect(x: 1_500, y: 0, width: 40, height: 24)
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(children: [
                Self.element(role: "AXMenuBarItem", frame: overhanging),
                Self.element(role: "AXMenuBarItem", frame: outside),
            ]),
        ])
        let collector = AppMenuTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set.targets == [
            HintTarget(
                frame: overhanging,
                clickPoint: CGPoint(x: 1_430, y: 12),
                role: "AXMenuBarItem",
            ),
        ])
    }

    @Test
    func `a bar with no frame gives an empty target set`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(
                children: [Self.element(role: "AXMenuBarItem", frame: Self.file)],
                barFrame: nil,
            ),
        ])
        let collector = AppMenuTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set.targets.isEmpty)
        #expect(set.rootFrame == .zero)
        #expect(set.pid == Self.pid)
    }

    @Test
    func `a read error propagates unchanged`() {
        let reader = FakeAccessibilityTreeReader(readError: .attributeUnsupported("AXMenuBar"))
        let collector = AppMenuTargetCollector(reader: reader)

        #expect(throws: AccessibilityReadError.attributeUnsupported("AXMenuBar")) {
            try collector.collect(from: Self.app)
        }
    }

    @Test
    func `an app without a process identifier is no process to read`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.snapshot(children: [])])
        let collector = AppMenuTargetCollector(reader: reader)

        #expect(throws: AccessibilityReadError.noSuchProcess(0)) {
            try collector.collect(from: FrontmostApp(name: "Helper"))
        }
        #expect(reader.readRequests.isEmpty)
    }

    @Test
    func `the app-menus trigger labels the titles in bar order and left-clicks the one typed`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(children: [
                Self.element(role: "AXMenuBarItem", frame: Self.apple),
                Self.element(role: "AXMenuBarItem", frame: Self.finder),
                Self.element(role: "AXMenuBarItem", frame: Self.file),
            ]),
        ])
        let presenter = FakeHintOverlayPresenter(screen: Self.barFrame.insetBy(dx: 0, dy: -400))
        let clicker = FakeClickPerformer()
        let turns = DeferredTurns()
        let session = HintSession(
            frontmostApp: FakeFrontmostAppProvider(answering: [Self.app]),
            collectors: [.appMenus: AppMenuTargetCollector(reader: reader)],
            presenter: presenter,
            clicker: clicker,
            configuration: { .default },
            deferToNextTurn: { turns.schedule($0) },
        )

        session.trigger(.appMenus)

        #expect(session.overlay?.entryPoint == .appMenus)
        #expect(session.overlay?.style == .filled)
        #expect(session.overlay?.chip == nil)
        #expect(session.overlay?.hints.map(\.label) == ["a", "s", "d"])

        presenter.type("d")
        turns.runAll()

        #expect(session.overlay == nil)
        #expect(clicker.clicks == [
            .init(point: CGPoint(x: Self.file.midX, y: Self.file.midY), button: .left),
        ])
    }
}
