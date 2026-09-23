import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// The collector reading what `TopmostContainerRule` resolves: another process's panel, a
/// context menu, or the frontmost app's focused window narrowed to its sheet or popover —
/// and falling back to the focused window when the resolved read finds nothing.
@MainActor
@Suite("WindowTargetCollector › the topmost container")
struct WindowTargetCollectorTopmostTests {
    typealias PID = TopmostContainerRuleTests.PID

    static let finder = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: PID.finder,
    )
    static let menuFrame = CGRect(x: 610, y: 400, width: 260, height: 120)
    static let contextMenuSignals = TopmostContainerRuleTests.signals(
        focused: PID.finder,
        extra: [TopmostContainerRuleTests.popUp(PID.finder, menuFrame)],
    )
    static let panelFrame = CGRect(x: 2_102, y: 24, width: 458, height: 800)
    static let controlCenterSignals = TopmostContainerRuleTests.signals(
        focused: PID.controlCenter,
        extra: [
            RaisedWindow(
                pid: PID.controlCenter,
                layer: 23,
                frame: panelFrame,
                isPopUpMenuLevel: false,
            ),
        ],
    )

    /// A context menu with two enabled items, the way the pop-up-menu read answers it.
    static let contextMenu = tree(
        [
            TopmostContainerNarrowingTests.element(
                role: "AXMenu",
                frame: menuFrame,
                depth: 0,
                parent: nil,
            ),
            ElementSnapshot(
                role: "AXMenuItem",
                subrole: nil,
                title: "Open",
                description: nil,
                frame: CGRect(x: 610, y: 405, width: 260, height: 22),
                isEnabled: true,
                actions: ["AXPress", "AXCancel"],
                depth: 1,
                parentIndex: 0,
            ),
            ElementSnapshot(
                role: "AXMenuItem",
                subrole: nil,
                title: "Get Info",
                description: nil,
                frame: CGRect(x: 610, y: 427, width: 260, height: 22),
                isEnabled: true,
                actions: ["AXPress", "AXCancel"],
                depth: 1,
                parentIndex: 0,
            ),
        ],
        pid: PID.finder,
        scope: .popUpMenu,
    )

    static let plainWindow = tree(
        TopmostContainerNarrowingTests.window(children: [
            TopmostContainerNarrowingTests.button(parent: 0),
        ]),
        pid: PID.finder,
        scope: .focusedWindow,
    )

    static func tree(_ elements: [ElementSnapshot], pid: pid_t, scope: ReadScope) -> TreeSnapshot {
        TreeSnapshot(
            bundleIdentifier: nil,
            pid: pid,
            scope: scope,
            strategy: .batchedPruned,
            elements: elements,
            readDuration: .milliseconds(9),
        )
    }

    @Test
    func `asks the probe once per press, before reading`() throws {
        let probe = FakeTopmostContainerProbe()
        let collector = WindowTargetCollector(
            reader: FakeAccessibilityTreeReader(readAnswers: [Self.plainWindow]),
            probe: probe,
        )

        _ = try collector.collect(from: Self.finder)
        _ = try collector.collect(from: Self.finder)

        #expect(probe.signalsCount == 2)
    }

    @Test
    func `an open context menu is read from the pop-up-menu scope and hinted`() throws {
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.contextMenu])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.contextMenuSignals),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(reader.readRequests.map(\.scope) == [.popUpMenu])
        #expect(reader.readRequests.map(\.pid) == [PID.finder])
        #expect(set.container == .contextMenu)
        #expect(set.rootFrame == Self.menuFrame)
        #expect(set.targets.map(\.clickPoint) == [
            CGPoint(x: 740, y: 416),
            CGPoint(x: 740, y: 438),
        ])
    }

    @Test
    func `a pop-up-menu window with no menu in it falls through to the focused window`() throws {
        // A Finder popover with a layer-101 window of its own, or a menu fading out: the
        // hit test finds no `AXMenu`, so the read answers "unsupported".
        let popoverWindow = Self.tree(
            TopmostContainerNarrowingTests.windowWithPopover,
            pid: PID.finder,
            scope: .focusedWindow,
        )
        let reader = FakeAccessibilityTreeReader(readResults: [
            .failure(.attributeUnsupported("AXMenu")),
            .success(popoverWindow),
        ])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.contextMenuSignals),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(reader.readRequests.map(\.scope) == [.popUpMenu, .focusedWindow])
        #expect(set.container == .popover)
        #expect(set.rootFrame == TopmostContainerNarrowingTests.popoverFrame)
        #expect(set.targets.map(\.role) == ["AXButton", "AXCheckBox"])
    }

    @Test
    func `another process's panel is read from that process, and the set carries its pid`() throws {
        let panel = Self.tree(
            [
                TopmostContainerNarrowingTests.element(
                    role: "AXWindow",
                    frame: Self.panelFrame,
                    depth: 0,
                    parent: nil,
                ),
                TopmostContainerNarrowingTests.button(
                    parent: 0,
                    frame: CGRect(x: 2_150, y: 80, width: 60, height: 60),
                ),
            ],
            pid: PID.controlCenter,
            scope: .focusedWindow,
        )
        let reader = FakeAccessibilityTreeReader(readAnswers: [panel])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.controlCenterSignals),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(reader.readRequests.map(\.pid) == [PID.controlCenter])
        #expect(set.pid == PID.controlCenter)
        #expect(set.container == .otherProcessPanel)
        #expect(set.targets.count == 1)
    }

    @Test(arguments: [
        AccessibilityReadError.attributeUnsupported("AXFocusedWindow"),
        .failed(code: -25_204),
        .noSuchProcess(PID.controlCenter),
    ])
    func `a panel that cannot be read falls back to the frontmost app's focused window`(
        error: AccessibilityReadError,
    ) throws {
        let reader = FakeAccessibilityTreeReader(readResults: [
            .failure(error),
            .success(Self.plainWindow),
        ])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.controlCenterSignals),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(reader.readRequests.map(\.pid) == [PID.controlCenter, PID.finder])
        #expect(set.pid == PID.finder)
        #expect(set.container == .focusedWindow)
    }

    @Test
    func `a missing grant is not fallen back from`() {
        let reader = FakeAccessibilityTreeReader(readResults: [
            .failure(.notTrusted),
            .success(Self.plainWindow),
        ])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.contextMenuSignals),
        )

        #expect(throws: AccessibilityReadError.notTrusted) {
            try collector.collect(from: Self.finder)
        }
        #expect(reader.readTreeCallCount == 1)
    }

    @Test
    func `with no menu and no focused window, the focused window's error is what is thrown`() {
        let reader = FakeAccessibilityTreeReader(readResults: [
            .failure(.attributeUnsupported("AXMenu")),
            .failure(.attributeUnsupported("AXFocusedWindow")),
        ])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: Self.contextMenuSignals),
        )

        #expect(throws: AccessibilityReadError.attributeUnsupported("AXFocusedWindow")) {
            try collector.collect(from: Self.finder)
        }
    }

    @Test
    func `a focused sheet is hinted whole`() throws {
        let sheet = Self.tree(
            TopmostContainerNarrowingTests.root(
                role: "AXSheet",
                subrole: nil,
                children: [TopmostContainerNarrowingTests.button(parent: 0)],
            ),
            pid: PID.finder,
            scope: .focusedWindow,
        )
        let collector = WindowTargetCollector(
            reader: FakeAccessibilityTreeReader(readAnswers: [sheet]),
            probe: FakeTopmostContainerProbe(),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(set.container == .sheet)
        #expect(set.rootFrame == TopmostContainerNarrowingTests.windowFrame)
        #expect(set.targets.count == 1)
    }

    @Test
    func `this process's own pid, taken by default, is never another process's panel`() throws {
        let own = ProcessInfo.processInfo.processIdentifier
        let signals = TopmostContainerRuleTests.signals(
            focused: own,
            extra: [TopmostContainerRuleTests.popUp(own, TopmostContainerRuleTests.screen)],
        )
        let reader = FakeAccessibilityTreeReader(readAnswers: [Self.plainWindow])
        let collector = WindowTargetCollector(
            reader: reader,
            probe: FakeTopmostContainerProbe(answering: signals),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(reader.readRequests.map(\.pid) == [PID.finder])
        #expect(set.container == .focusedWindow)
    }
}

// MARK: - A popover in a sheet

extension WindowTargetCollectorTopmostTests {
    @Test
    func `a popover open in a focused sheet is hinted, not the sheet behind it`() throws {
        let sheet = Self.tree(
            TopmostContainerNarrowingTests.sheetWithPopover,
            pid: PID.finder,
            scope: .focusedWindow,
        )
        let collector = WindowTargetCollector(
            reader: FakeAccessibilityTreeReader(readAnswers: [sheet]),
            probe: FakeTopmostContainerProbe(),
        )

        let set = try collector.collect(from: Self.finder)

        #expect(set.container == .popover)
        #expect(set.rootFrame == TopmostContainerNarrowingTests.popoverFrame)
        #expect(set.targets.map(\.role) == ["AXButton", "AXCheckBox"])
    }
}
