import AppKit
import HintjumpCore
@testable import HintjumpPlatform
import Testing

/// The overlay adapter against the real window server and the real screens.
///
/// What a Core test with ``FakeHintOverlayPresenter`` cannot ask: does the flip between
/// the port's top-left-origin coordinates and AppKit's land the panel where the session
/// placed it, does a key event's characters really become the ``HintKey`` the session
/// expects, and does taking the overlay down stay silent? Needs no TCC grant — only a
/// logged-in GUI session with a display.
///
/// It never takes the developer's keyboard focus: the panel it shows is transparent,
/// click-through, and built unable to become key, and key events are handed to the panel
/// directly rather than typed. So nothing the developer types or clicks meanwhile reaches
/// it, and no assertion here counts anything the developer could cause. That a real
/// panel does become key without activating Hintjump is the one part this cannot see; it
/// is left to the last rung of `AGENTS.md`'s "How far verification goes": the developer's
/// Mac, announced first. Serialized: every case shares the one screen.
@Suite(
    "PanelHintOverlayPresenter against the real window server",
    .requiresLocalMachine,
    .serialized,
)
@MainActor
struct PanelHintOverlayPresenterTests {
    /// A presenter whose panel never becomes key, so showing it leaves the developer's
    /// keyboard focus where it is.
    private static func quietPresenter() -> PanelHintOverlayPresenter {
        PanelHintOverlayPresenter(panel: HintOverlayPanel(takesKeyFocus: false))
    }

    private static func primaryScreen() throws -> NSScreen {
        try LocalMachineTests.require(
            NSScreen.screens.first,
            requires: "a logged-in GUI session with a display",
            grant: false,
        )
    }

    private static func keyEvent(
        _ type: NSEvent.EventType,
        characters: String,
        isARepeat: Bool = false,
    ) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: isARepeat,
            keyCode: 0,
        ))
    }

    @Test
    func `the screen holding the primary screen's center is the primary screen at the origin`(
    ) throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let primary = try Self.primaryScreen().frame
        let presenter = PanelHintOverlayPresenter()

        let frame = presenter.screenFrame(containing: CGPoint(x: primary.midX, y: primary.midY))

        #expect(frame == CGRect(origin: .zero, size: primary.size))
    }

    @Test
    func `a point on no screen has no screen frame`() {
        let presenter = PanelHintOverlayPresenter()

        #expect(presenter.screenFrame(containing: CGPoint(x: -1_000_000, y: -1_000_000)) == nil)
    }

    @Test
    func `show covers the canvas flipped into AppKit's coordinates, and hide takes it down`(
    ) throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let primary = try Self.primaryScreen().frame
        let presenter = Self.quietPresenter()
        let canvas = CGRect(x: 40, y: 60, width: 300, height: 200)

        presenter.show(
            canvas: canvas,
            onKey: { _ in
                // Nothing types into a panel that cannot become key.
            },
            onDismiss: {
                // A click of the developer's elsewhere may land here; it is not counted.
            },
        )
        OwnEventQueue.drain(for: OwnEventQueue.settleTime)

        #expect(presenter.panel.isVisible)
        #expect(!presenter.panel.isKeyWindow)
        #expect(presenter.isWatchingMouseDowns)
        #expect(presenter.panel.frame == CGRect(
            x: 40,
            y: primary.height - 260,
            width: 300,
            height: 200,
        ))

        presenter.hide()
        OwnEventQueue.drain(for: OwnEventQueue.settleTime)

        #expect(!presenter.panel.isVisible)
        #expect(!presenter.isWatchingMouseDowns)
        #expect(presenter.panel.onKey == nil)
        #expect(presenter.panel.onResignKey == nil)
    }

    /// No event is dispatched between `show` and the resignation, so a click of the
    /// developer's cannot reach the mouse-down monitor and add a dismissal of its own.
    @Test
    func `losing key status while shown is one dismissal, and after hide it is none`() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let presenter = Self.quietPresenter()
        var dismissals = 0

        presenter.show(
            canvas: CGRect(x: 40, y: 60, width: 300, height: 200),
            onKey: { _ in
                // Not what this test is about.
            },
            onDismiss: { dismissals += 1 },
        )
        presenter.panel.resignKey()

        #expect(dismissals == 1)

        presenter.hide()
        presenter.panel.resignKey()

        #expect(dismissals == 1)
    }

    @Test(arguments: [
        ("a", HintKey.character("a")),
        ("A", HintKey.character("A")),
        ("\u{1B}", HintKey.escape),
        ("\u{7F}", HintKey.backspace),
        ("\u{08}", HintKey.backspace),
    ])
    func `a key-down's characters become the key the session reads`(
        characters: String,
        expected: HintKey,
    ) throws {
        let panel = HintOverlayPanel(takesKeyFocus: false)
        var keys: [HintKey] = []
        panel.onKey = { keys.append($0) }

        try panel.sendEvent(Self.keyEvent(.keyDown, characters: characters))

        #expect(keys == [expected])
    }

    @Test
    func `a key-up, an auto-repeat, and a composed sequence reach no handler`() throws {
        let panel = HintOverlayPanel(takesKeyFocus: false)
        var keys: [HintKey] = []
        panel.onKey = { keys.append($0) }

        try panel.sendEvent(Self.keyEvent(.keyUp, characters: "a"))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: "a", isARepeat: true))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: "ab"))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: ""))

        #expect(keys.isEmpty)
    }
}
