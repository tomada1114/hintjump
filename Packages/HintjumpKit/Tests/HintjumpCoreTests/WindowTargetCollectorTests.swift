import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// Reading the frontmost window and turning it into hint targets, against
/// `FakeAccessibilityTreeReader`.
@MainActor
@Suite("WindowTargetCollector")
struct WindowTargetCollectorTests {
    static let pid: pid_t = 4_242
    static let app = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: pid,
    )
    static let windowFrame = CGRect(x: 0, y: 0, width: 900, height: 600)

    /// An element under the window (or under `parent`), clickable through `AXPress`
    /// unless `actions` says otherwise.
    private static func element(
        role: String,
        frame: CGRect?,
        parent: Int = 0,
        actions: [String] = ["AXPress"],
    ) -> ElementSnapshot {
        ElementSnapshot(
            role: role,
            subrole: nil,
            title: "Private title",
            description: nil,
            frame: frame,
            isEnabled: true,
            actions: actions,
            depth: parent + 1,
            parentIndex: parent,
        )
    }

    /// A `.focusedWindow` snapshot whose root is a window at `rootFrame`, followed by
    /// `children`.
    private static func snapshot(
        children: [ElementSnapshot],
        rootFrame: CGRect? = windowFrame,
    ) -> TreeSnapshot {
        let window = ElementSnapshot(
            role: "AXWindow",
            subrole: "AXStandardWindow",
            title: nil,
            description: nil,
            frame: rootFrame,
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        return TreeSnapshot(
            bundleIdentifier: "com.apple.finder",
            pid: pid,
            scope: .focusedWindow,
            strategy: .batchedPruned,
            elements: [window] + children,
            readDuration: .milliseconds(12),
        )
    }

    @Test
    func `reads the frontmost app's focused window with the batchedPruned strategy`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.snapshot(children: [])])
        let collector = WindowTargetCollector(reader: reader)

        _ = try collector.collect(from: Self.app)

        #expect(reader.readRequests == [
            .init(pid: Self.pid, scope: .focusedWindow, strategy: .batchedPruned, maxDepth: nil),
        ])
    }

    @Test
    func `ranks clickable elements into targets clicked at their visible centers`() throws {
        let lower = CGRect(x: 100, y: 300, width: 40, height: 20)
        let upper = CGRect(x: 200, y: 100, width: 40, height: 20)
        // Its center (10, 510) is inside the window, but its left 10 pt are not.
        let clipped = CGRect(x: -10, y: 500, width: 40, height: 20)
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(children: [
                Self.element(role: "AXButton", frame: lower),
                Self.element(
                    role: "AXStaticText",
                    frame: CGRect(x: 0, y: 0, width: 50, height: 20),
                    actions: [],
                ),
                Self.element(role: "AXButton", frame: upper),
                Self.element(role: "AXButton", frame: clipped),
            ]),
        ])
        let collector = WindowTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set == TargetSet(
            pid: Self.pid,
            bundleIdentifier: "com.apple.finder",
            rootFrame: Self.windowFrame,
            targets: [
                HintTarget(frame: upper, clickPoint: CGPoint(x: 220, y: 110), role: "AXButton"),
                HintTarget(frame: lower, clickPoint: CGPoint(x: 120, y: 310), role: "AXButton"),
                HintTarget(frame: clipped, clickPoint: CGPoint(x: 15, y: 510), role: "AXButton"),
            ],
            readDuration: .milliseconds(12),
        ))
    }

    @Test
    func `a window with no frame gives an empty target set`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            Self.snapshot(
                children: [
                    Self.element(
                        role: "AXButton",
                        frame: CGRect(x: 100, y: 100, width: 40, height: 20),
                    ),
                ],
                rootFrame: nil,
            ),
        ])
        let collector = WindowTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)

        #expect(set.targets.isEmpty)
        #expect(set.rootFrame == .zero)
        #expect(set.pid == Self.pid)
    }

    @Test
    func `a read error propagates unchanged`() {
        let reader =
            FakeAccessibilityTreeReader(readError: .attributeUnsupported("AXFocusedWindow"))
        let collector = WindowTargetCollector(reader: reader)

        #expect(throws: AccessibilityReadError.attributeUnsupported("AXFocusedWindow")) {
            try collector.collect(from: Self.app)
        }
    }

    @Test
    func `an app without a process identifier is no process to read`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.snapshot(children: [])])
        let collector = WindowTargetCollector(reader: reader)

        #expect(throws: AccessibilityReadError.noSuchProcess(0)) {
            try collector.collect(from: FrontmostApp(name: "Helper"))
        }
        #expect(reader.readRequests.isEmpty)
    }

    @Test
    func `an empty AXWebArea is woken once per process and the second read is ranked`() throws {
        let button = CGRect(x: 100, y: 100, width: 40, height: 20)
        let empty = Self.snapshot(children: [
            Self.element(role: "AXWebArea", frame: Self.windowFrame, actions: []),
        ])
        let populated = Self.snapshot(children: [
            Self.element(role: "AXWebArea", frame: Self.windowFrame, actions: []),
            Self.element(role: "AXButton", frame: button, parent: 1),
        ])
        let reader = FakeAccessibilityTreeReader(readAnswers: [empty, populated, empty])
        let collector = WindowTargetCollector(reader: reader)

        let set = try collector.collect(from: Self.app)
        _ = try collector.collect(from: Self.app)

        #expect(set.targets.map(\.frame) == [button])
        #expect(reader.enableManualAccessibilityCalls == [Self.pid])
        #expect(reader.readTreeCallCount == 3)
    }
}
