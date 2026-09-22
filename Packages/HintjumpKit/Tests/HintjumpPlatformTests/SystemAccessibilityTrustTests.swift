import HintjumpCore
import HintjumpPlatform
import Testing

/// The adapter against the real `ApplicationServices` API.
///
/// What a Core test with a fake cannot ask — does `AXIsProcessTrusted()` really answer
/// true for a process that holds the grant? Everything downstream of that answer (what
/// state the app shows, when it prompts) stays a Core test against
/// `FakeAccessibilityTrustChecking`, where the coverage floor sees it.
///
/// Needs the Accessibility grant, held by the application that launched the run, so
/// `just test-local` from a terminal that has it — the read is unwrapped through
/// `LocalMachineTests.require(_:requires:grant:)` so a missing grant names itself
/// instead of reading as a broken adapter.
@Suite("SystemAccessibilityTrust against the real ApplicationServices API", .requiresLocalMachine)
@MainActor
struct SystemAccessibilityTrustTests {
    @Test
    func `isTrusted answers true for a process that holds the Accessibility grant`() throws {
        let trust = SystemAccessibilityTrust()

        let isTrusted = try LocalMachineTests.require(
            trust.isTrusted ? true : nil,
            requires: "the Accessibility grant",
            grant: true,
        )

        #expect(isTrusted)
    }
}
