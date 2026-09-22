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
/// It shows a transparent, click-through panel of its own for a moment and makes it key,
/// so keyboard focus leaves the frontmost app briefly; it posts no event to any other
/// window. Serialized: every case shares the one screen.
@Suite(
    "PanelHintOverlayPresenter against the real window server",
    .requiresLocalMachine,
    .serialized,
)
@MainActor
struct PanelHintOverlayPresenterTests {
    /// Long enough for the window server to order a window in or out, and for a late
    /// resignation to arrive.
    static let settleTime: TimeInterval = 0.3

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
    func `show covers the canvas flipped into AppKit's coordinates, and hide takes it down silently`(
    ) throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let primary = try Self.primaryScreen().frame
        let presenter = PanelHintOverlayPresenter()
        let canvas = CGRect(x: 40, y: 60, width: 300, height: 200)
        var keys: [HintKey] = []
        var dismissals = 0

        presenter.show(
            canvas: canvas,
            onKey: { keys.append($0) },
            onDismiss: { dismissals += 1 },
        )
        ClickTargetWindow.spinRunLoop(for: Self.settleTime)

        #expect(presenter.panel.isVisible)
        #expect(presenter.panel.frame == CGRect(
            x: 40,
            y: primary.height - 260,
            width: 300,
            height: 200,
        ))

        presenter.hide()
        ClickTargetWindow.spinRunLoop(for: Self.settleTime)

        #expect(!presenter.panel.isVisible)
        #expect(keys.isEmpty)
        #expect(dismissals == 0)
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
        let panel = HintOverlayPanel()
        var keys: [HintKey] = []
        panel.onKey = { keys.append($0) }

        try panel.sendEvent(Self.keyEvent(.keyDown, characters: characters))

        #expect(keys == [expected])
    }

    @Test
    func `a key-up, an auto-repeat, and a composed sequence reach no handler`() throws {
        let panel = HintOverlayPanel()
        var keys: [HintKey] = []
        panel.onKey = { keys.append($0) }

        try panel.sendEvent(Self.keyEvent(.keyUp, characters: "a"))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: "a", isARepeat: true))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: "ab"))
        try panel.sendEvent(Self.keyEvent(.keyDown, characters: ""))

        #expect(keys.isEmpty)
    }
}
