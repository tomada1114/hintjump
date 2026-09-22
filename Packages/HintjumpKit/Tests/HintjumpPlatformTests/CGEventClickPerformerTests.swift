import ApplicationServices
import HintjumpCore
import HintjumpPlatform
import Testing

/// The adapter against the real event system, in two suites that can never both run:
/// one needs the Accessibility grant and the other needs it absent.
///
/// What a Core test with a fake cannot ask — does a click posted at the HID level really
/// reach the window under the point as one press of the right button, and does the adapter
/// really refuse, rather than post into nothing, without the grant? Which point to click
/// stays a Core decision with a Core test (`.claude/rules/testing.md` › Where a Test Goes).
@Suite("CGEventClickPerformer against the real event system", .requiresLocalMachine)
enum CGEventClickPerformerTests {
    /// **This suite moves the pointer and clicks.** It clicks only its own
    /// ``ClickTargetWindow``, and ``ClickTargetWindow/clickPoint()`` refuses to answer
    /// unless that window is the topmost one at its center, so a click can never land on
    /// something of the user's; still, keep hands off the Mac for the few seconds it runs
    /// (`AGENTS.md` › "Security and human approval"). Needs the Accessibility grant, held
    /// by the application that launched the run.
    ///
    /// Serialized: both cases show a window at the same spot, and two at once would each
    /// catch the other's click. It repeats the enclosing suite's `.requiresLocalMachine`
    /// so that the opt-in guarding a real click is visible where the click is.
    @Suite("clicking the test's own window", .requiresLocalMachine, .serialized)
    @MainActor
    struct ClicksOwnWindow {
        @Test(arguments: [MouseButton.left, .right])
        func `a click reaches the window under the point once, as that button, and leaves the pointer there`(
            button: MouseButton,
        ) throws {
            _ = try LocalMachineTests.require(
                AXIsProcessTrusted() ? true : nil,
                requires: "the Accessibility grant",
                grant: true,
            )
            let target = try ClickTargetWindow()
            defer { target.close() }
            let point = try target.clickPoint()

            try CGEventClickPerformer().click(at: point, button: button)
            ClickTargetWindow.spinRunLoop(for: ClickTargetWindow.settleTime)

            let expected = ClickRecordingView.Press(button: button, clickCount: 1)
            #expect(target.recorder.presses == [expected])
            let pointer = try #require(CGEvent(source: nil)?.location)
            #expect(
                abs(pointer.x - point.x) <= 1 && abs(pointer.y - point.y) <= 1,
                "pointer at \(pointer), clicked \(point)",
            )
        }
    }

    /// Without the grant the OS would drop the click silently, and Core could not tell
    /// that apart from a click that landed. Runs only where the grant is absent, so on a
    /// developer's machine that holds it this reports as skipped. It posts nothing either
    /// way: the `#require` stops the test before `click` if the grant turns out present.
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
                try CGEventClickPerformer().click(at: .zero, button: .left)
            }
        }
    }
}
