import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// `TopmostContainerRule` against every row of `docs/research/topmost-container.md`, each
/// fed the signals #9's runs recorded for it.
///
/// The screen is the one those runs used — a 2,560 × 1,440 primary display — and every
/// row carries the windows that were on screen throughout ("Noise the rule has to
/// ignore"): Notification Center's full-screen layer-21 window, the Dock's layer-20 one,
/// the screenshot service's layer-24 one, a third-party layer-3 window, and Control
/// Center's status items in the menu bar strip.
@Suite("TopmostContainerRule")
struct TopmostContainerRuleTests {
    typealias Tree = TopmostContainerNarrowingTests

    enum PID {
        static let finder: pid_t = 400
        static let textEdit: pid_t = 410
        static let controlCenter: pid_t = 500
        static let notificationCenter: pid_t = 600
        static let spotlight: pid_t = 700
        static let launcher: pid_t = 800
        static let dock: pid_t = 900
        static let screenshot: pid_t = 950
        static let thirdParty: pid_t = 1_200
        static let hintjump: pid_t = 999
    }

    static let screen = CGRect(x: 0, y: 0, width: 2_560, height: 1_440)
    static let menuBarHeight: CGFloat = 24
    static let popUpMenuLayer = 101

    /// The windows above the normal layer that were on screen in every run.
    static let alwaysOnScreen = [
        RaisedWindow(
            pid: PID.controlCenter,
            layer: 25,
            frame: CGRect(x: 2_300, y: 0, width: 30, height: 24),
            isPopUpMenuLevel: false,
        ),
        RaisedWindow(
            pid: PID.controlCenter,
            layer: 25,
            frame: CGRect(x: 2_400, y: 0, width: 143, height: 24),
            isPopUpMenuLevel: false,
        ),
        RaisedWindow(pid: PID.screenshot, layer: 24, frame: screen, isPopUpMenuLevel: false),
        RaisedWindow(
            pid: PID.notificationCenter,
            layer: 21,
            frame: screen,
            isPopUpMenuLevel: false,
        ),
        RaisedWindow(pid: PID.dock, layer: 20, frame: screen, isPopUpMenuLevel: false),
        RaisedWindow(
            pid: PID.thirdParty,
            layer: 3,
            frame: CGRect(x: 40, y: 900, width: 300, height: 200),
            isPopUpMenuLevel: false,
        ),
    ]

    /// A pop-up-menu-level window `pid` owns at `frame`.
    static func popUp(_ pid: pid_t, _ frame: CGRect) -> RaisedWindow {
        RaisedWindow(pid: pid, layer: popUpMenuLayer, frame: frame, isPopUpMenuLevel: true)
    }

    /// The signals with `focused` as the system-wide focused application and only the
    /// windows that are always there.
    static func signals(focused: pid_t?) -> TopmostContainerSignals {
        signals(focused: focused, extra: [])
    }

    /// The signals with `focused` as the system-wide focused application and `extra`
    /// listed in front of the windows that are always there.
    static func signals(focused: pid_t?, extra: [RaisedWindow]) -> TopmostContainerSignals {
        TopmostContainerSignals(
            focusedApplicationPID: focused,
            menuBarHeight: menuBarHeight,
            raisedWindows: extra + alwaysOnScreen,
        )
    }

    static func resolve(_ signals: TopmostContainerSignals, frontmost: pid_t) -> TopmostRead {
        TopmostContainerRule.resolve(signals, frontmostPID: frontmost, ownPID: PID.hintjump)
    }

    static func focusedWindow(of pid: pid_t) -> TopmostRead {
        TopmostRead(pid: pid, scope: .focusedWindow, container: .focusedWindow)
    }

    // MARK: - The table's rows

    @Test
    func `nothing special: the focused window`() {
        let read = Self.resolve(Self.signals(focused: PID.finder), frontmost: PID.finder)

        #expect(read == Self.focusedWindow(of: PID.finder))
        let window = Tree.window(children: [Tree.button(parent: 0)])
        #expect(TopmostContainerRule.container(in: window).container == .focusedWindow)
    }

    @Test
    func `app menu open: its pop-up-menu-level window matches check 2, as the rule says`() {
        // The hotkey is never delivered while a menu-bar menu tracks, so this read is
        // never made; the rule would read the menu if it were.
        let file = Self.popUp(PID.finder, CGRect(x: 180, y: 24, width: 239, height: 280))
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [file]),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(pid: PID.finder, scope: .popUpMenu, container: .contextMenu))
    }

    @Test
    func `context menu open: the frontmost app's pop-up-menu-level window`() {
        let menu = Self.popUp(PID.finder, CGRect(x: 610, y: 400, width: 260, height: 560))
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [menu]),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(pid: PID.finder, scope: .popUpMenu, container: .contextMenu))
    }

    @Test
    func `popover: no window of its own, found inside the focused window's read`() throws {
        let read = Self.resolve(Self.signals(focused: PID.finder), frontmost: PID.finder)
        #expect(read == Self.focusedWindow(of: PID.finder))

        let narrowed = TopmostContainerRule
            .container(in: Tree.windowWithPopover)

        #expect(narrowed.container == .popover)
        let root = try #require(narrowed.elements.first)
        #expect(root.role == "AXPopover")
        #expect(root.frame == Tree.popoverFrame)
    }

    @Test(arguments: ["save panel", "save-changes alert"])
    func `sheet and alert: the focused window is an AXSheet`(_: String) {
        let read = Self.resolve(Self.signals(focused: PID.textEdit), frontmost: PID.textEdit)
        #expect(read == Self.focusedWindow(of: PID.textEdit))

        let sheet = Tree.root(
            role: "AXSheet",
            subrole: nil,
            children: [Tree.button(parent: 0)],
        )
        let narrowed = TopmostContainerRule.container(in: sheet)

        #expect(narrowed.container == .sheet)
        #expect(narrowed.elements == sheet)
    }

    @Test
    func `floating panel: not focused, so the focused window is targeted`() {
        let fonts = RaisedWindow(
            pid: PID.textEdit,
            layer: 3,
            frame: CGRect(x: 1_800, y: 200, width: 440, height: 520),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.textEdit, extra: [fonts]),
            frontmost: PID.textEdit,
        )

        #expect(read == Self.focusedWindow(of: PID.textEdit))
    }

    @Test
    func `status-item panel from another process: Control Center's focused window`() {
        let wifi = RaisedWindow(
            pid: PID.controlCenter,
            layer: 23,
            frame: CGRect(x: 2_102, y: 24, width: 458, height: 1_387),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.controlCenter, extra: [wifi]),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(
            pid: PID.controlCenter,
            scope: .focusedWindow,
            container: .otherProcessPanel,
        ))
    }

    @Test
    func `notification Center: its full-screen window once it has focus`() {
        let read = Self.resolve(
            Self.signals(focused: PID.notificationCenter),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(
            pid: PID.notificationCenter,
            scope: .focusedWindow,
            container: .otherProcessPanel,
        ))
    }

    @Test
    func `spotlight: its two layer-23 windows once it has focus`() {
        let outer = RaisedWindow(
            pid: PID.spotlight,
            layer: 23,
            frame: CGRect(x: 920, y: 300, width: 720, height: 136),
            isPopUpMenuLevel: false,
        )
        let field = RaisedWindow(
            pid: PID.spotlight,
            layer: 23,
            frame: CGRect(x: 960, y: 340, width: 640, height: 56),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.spotlight, extra: [field, outer]),
            frontmost: PID.finder,
        )

        #expect(read.pid == PID.spotlight)
        #expect(read.container == .otherProcessPanel)
    }
}
