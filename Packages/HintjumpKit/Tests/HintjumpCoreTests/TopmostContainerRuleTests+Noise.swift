import CoreGraphics
import HintjumpCore
import Testing

/// The rows #9's runs added to the issue's table, the noise
/// `docs/research/topmost-container.md` lists, and the bounds of check 1.
extension TopmostContainerRuleTests {
    // MARK: - Rows the runs added

    @Test
    func `a third-party launcher at layer 8 is another process's panel`() {
        let launcher = RaisedWindow(
            pid: PID.launcher,
            layer: 8,
            frame: CGRect(x: 900, y: 300, width: 750, height: 475),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.launcher, extra: [launcher]),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(
            pid: PID.launcher,
            scope: .focusedWindow,
            container: .otherProcessPanel,
        ))
    }

    @Test
    func `a popover with its own pop-up-menu-level window is hit-tested first`() {
        // The hit test finds no menu in it, so the collector falls through to the focused
        // window, where the popover is (`WindowTargetCollectorTests`).
        let popover = Self.popUp(PID.finder, Tree.popoverFrame)
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [popover]),
            frontmost: PID.finder,
        )

        #expect(read.scope == .popUpMenu)
    }

    @Test
    func `a submenu of a context menu is a second pop-up-menu-level window`() {
        let submenu = Self.popUp(PID.finder, CGRect(x: 870, y: 700, width: 240, height: 300))
        let menu = Self.popUp(PID.finder, CGRect(x: 610, y: 400, width: 260, height: 560))
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [submenu, menu]),
            frontmost: PID.finder,
        )

        #expect(read == TopmostRead(pid: PID.finder, scope: .popUpMenu, container: .contextMenu))
    }

    @Test
    func `a menu inside Notification Center: check 1 wins over the pop-up-menu level`() {
        let menu = Self.popUp(
            PID.notificationCenter,
            CGRect(x: 2_200, y: 100, width: 200, height: 120),
        )
        let read = Self.resolve(
            Self.signals(focused: PID.notificationCenter, extra: [menu]),
            frontmost: PID.finder,
        )

        #expect(read.pid == PID.notificationCenter)
        #expect(read.container == .otherProcessPanel)
    }

    @Test
    func `the desktop: Finder's focused scroll area is the focused window`() {
        let read = Self.resolve(Self.signals(focused: PID.finder), frontmost: PID.finder)
        #expect(read == Self.focusedWindow(of: PID.finder))

        let desktop = Tree.root(
            role: "AXScrollArea",
            subrole: nil,
            children: [],
        )
        #expect(TopmostContainerRule.container(in: desktop).container == .focusedWindow)
    }

    // MARK: - Noise the rule has to ignore

    @Test
    func `this app's own overlay taking focus is not another process's panel`() {
        let overlay = Self.popUp(PID.hintjump, Self.screen)
        let read = Self.resolve(
            Self.signals(focused: PID.hintjump, extra: [overlay]),
            frontmost: PID.finder,
        )

        #expect(read == Self.focusedWindow(of: PID.finder))
    }

    @Test
    func `a Spotlight window still closing after focus came back is ignored`() {
        let closing = RaisedWindow(
            pid: PID.spotlight,
            layer: 23,
            frame: CGRect(x: 920, y: 300, width: 720, height: 400),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [closing]),
            frontmost: PID.finder,
        )

        #expect(read == Self.focusedWindow(of: PID.finder))
    }

    @Test
    func `no answer for the focused application means no other panel`() {
        // `kAXErrorCannotComplete` on an Electron app's first read, or no grant.
        let read = Self.resolve(Self.signals(focused: nil), frontmost: PID.finder)

        #expect(read == Self.focusedWindow(of: PID.finder))
    }

    @Test
    func `a focused process whose only raised windows are in the menu bar strip has no panel`() {
        // Control Center focused with only its status items on screen.
        let read = Self.resolve(Self.signals(focused: PID.controlCenter), frontmost: PID.finder)

        #expect(read == Self.focusedWindow(of: PID.finder))
    }

    @Test(arguments: [
        (CGFloat(40), false),
        (41, true),
    ])
    func `another process's window must be taller than 40 pt`(height: CGFloat, isPanel: Bool) {
        let window = RaisedWindow(
            pid: PID.launcher,
            layer: 8,
            frame: CGRect(x: 900, y: 300, width: 600, height: height),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.launcher, extra: [window]),
            frontmost: PID.finder,
        )

        #expect((read.container == .otherProcessPanel) == isPanel)
    }

    @Test(arguments: [
        (CGFloat(0), false), // wholly inside the strip: y 0…24
        (1, true), // reaches 1 pt below it
    ])
    func `another process's window must not lie wholly inside the menu bar strip`(
        overhang: CGFloat,
        isPanel: Bool,
    ) {
        // Taller than 40 pt so only the strip test decides; a frame this tall inside a
        // 24 pt strip starts above the screen, which is what makes it "wholly inside".
        let window = RaisedWindow(
            pid: PID.launcher,
            layer: 8,
            frame: CGRect(x: 900, y: -40 + overhang, width: 100, height: 64),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.launcher, extra: [window]),
            frontmost: PID.finder,
        )

        #expect((read.container == .otherProcessPanel) == isPanel)
    }

    @Test
    func `a pop-up-menu-level window of a process other than the frontmost one is not its menu`() {
        let other = Self.popUp(PID.thirdParty, CGRect(x: 100, y: 100, width: 200, height: 300))
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [other]),
            frontmost: PID.finder,
        )

        #expect(read == Self.focusedWindow(of: PID.finder))
    }

    @Test
    func `the frontmost app's tiny layer-3 dialogs change nothing`() {
        let blip = RaisedWindow(
            pid: PID.finder,
            layer: 3,
            frame: CGRect(x: 10, y: 900, width: 84, height: 77),
            isPopUpMenuLevel: false,
        )
        let read = Self.resolve(
            Self.signals(focused: PID.finder, extra: [blip]),
            frontmost: PID.finder,
        )

        #expect(read == Self.focusedWindow(of: PID.finder))
    }
}
