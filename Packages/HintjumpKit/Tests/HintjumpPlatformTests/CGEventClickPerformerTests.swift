import AppKit
import HintjumpCore
@testable import HintjumpPlatform
import Testing

/// What a posted mouse event looks like to the app that receives it.
struct ReceivedMouseEvent: Equatable {
    let type: NSEvent.EventType
    let clickCount: Int
    let location: CGPoint
}

/// The adapter against the real event system, in two suites that can never both run:
/// one needs the Accessibility grant and the other needs it absent.
///
/// What a Core test with a fake cannot ask — are the events the adapter builds really one
/// press and one release of the right button, a first click, at the point, as an app
/// reads them? And does the adapter really refuse, rather than post into nothing,
/// without the grant? Which point to click stays a Core decision with a Core test
/// (`.claude/rules/testing.md` › Where a Test Goes).
///
/// It never touches the developer's pointer or windows: the events are posted to this
/// test process alone (``CGEventClickPerformer/Delivery/process(_:)``) and read back from
/// its own queue. The HID route the product takes — the pointer moving to the point and
/// the window server handing the click to the window under it — is the one part this
/// cannot see; it is left to the last rung of `AGENTS.md`'s "How far verification goes":
/// the developer's Mac, announced first.
@Suite("CGEventClickPerformer against the real event system", .requiresLocalMachine)
enum CGEventClickPerformerTests {
    /// Needs the Accessibility grant, held by the application that launched the run.
    ///
    /// Serialized so the two cases never share the queue they read back from. It repeats
    /// the enclosing suite's `.requiresLocalMachine` so that the opt-in guarding a posted
    /// click is visible where the click is.
    @Suite("clicking into the test's own event queue", .requiresLocalMachine, .serialized)
    @MainActor
    struct ClicksOwnProcess {
        /// On no display: the events carry the point as their location, and nothing at
        /// the point is meant to receive them.
        static let point = CGPoint(x: -20_000, y: -20_000)

        static func types(for button: MouseButton) -> [NSEvent.EventType] {
            switch button {
            case .left:
                [.leftMouseDown, .leftMouseUp]

            case .right:
                [.rightMouseDown, .rightMouseUp]
            }
        }

        @Test(arguments: [MouseButton.left, .right])
        func `a click arrives as one press and one release of that button at the point`(
            button: MouseButton,
        ) throws {
            _ = try LocalMachineTests.require(
                AXIsProcessTrusted() ? true : nil,
                requires: "the Accessibility grant",
                grant: true,
            )
            let mouseTypes: Set<NSEvent.EventType> = [
                .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            ]

            try CGEventClickPerformer(delivery: .process(getpid())).click(
                at: Self.point,
                button: button,
            )
            let received = OwnEventQueue.drain(for: OwnEventQueue.settleTime)
                .filter { mouseTypes.contains($0.type) }
                .map { event in
                    ReceivedMouseEvent(
                        type: event.type,
                        clickCount: event.clickCount,
                        location: event.cgEvent?.location ?? .zero,
                    )
                }

            let expected = Self.types(for: button).map { type in
                ReceivedMouseEvent(type: type, clickCount: 1, location: Self.point)
            }
            #expect(received == expected)
        }
    }

    /// Without the grant the OS would drop the click silently, and Core could not tell
    /// that apart from a click that landed. Runs only where the grant is absent, so on a
    /// developer's machine that holds it this reports as skipped. It posts nothing either
    /// way: the `#require` stops the test before `click` if the grant turns out present,
    /// and the performer delivers to this process only, like the suite above.
    @Suite("without the Accessibility grant", .requiresLocalMachine)
    @MainActor
    struct WithoutGrant {
        @Test(.enabled(
            if: !AXIsProcessTrusted(),
            "runs only in a process without the Accessibility grant",
        ))
        func `click throws notTrusted instead of posting into nothing`() throws {
            try #require(
                !AXIsProcessTrusted(),
                "the grant is present; clicking now would post a real click",
            )

            #expect(throws: ClickError.notTrusted) {
                try CGEventClickPerformer(delivery: .process(getpid()))
                    .click(at: .zero, button: .left)
            }
        }
    }
}
