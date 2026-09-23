import HintjumpCore
import Testing

/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation whose answers are data, and whose calls are recorded in a value the
/// test reads afterwards. Modeled on `FakeFrontmostAppProvider`, and shared with
/// `SettingsViewModelTests`, which reads the gate's state through the same port.
@MainActor
final class FakeAccessibilityTrustChecking: AccessibilityTrustChecking {
    /// What ``isTrusted`` answers on the next read.
    var isTrusted = false
    private(set) var requestTrustCallCount = 0

    func requestTrust() {
        requestTrustCallCount += 1
    }
}

@MainActor
@Suite("AccessibilityGateViewModel")
struct AccessibilityGateViewModelTests {
    @Test
    func `starts unknown, before anything asks the port`() {
        let trust = FakeAccessibilityTrustChecking()
        let model = AccessibilityGateViewModel(trust: trust)
        #expect(model.state == .unknown)
        #expect(model.hasPrompted == false)
        #expect(trust.requestTrustCallCount == 0)
    }

    @Test
    func `refresh flips to ready when the port reports trusted`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = true
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        #expect(model.state == .ready)
    }

    @Test
    func `refresh flips to blocked when the port reports not trusted`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = false
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        #expect(model.state == .blocked)
    }

    @Test
    func `each refresh asks the port again and takes the newer answer`() {
        let trust = FakeAccessibilityTrustChecking()
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        #expect(model.state == .blocked)
        trust.isTrusted = true
        model.refresh()
        #expect(model.state == .ready)
        trust.isTrusted = false
        model.refresh()
        #expect(model.state == .blocked)
    }

    @Test
    func `promptIfNeeded does nothing before a refresh has run`() {
        let trust = FakeAccessibilityTrustChecking()
        let model = AccessibilityGateViewModel(trust: trust)
        model.promptIfNeeded()
        #expect(trust.requestTrustCallCount == 0)
        #expect(model.hasPrompted == false)
    }

    @Test
    func `promptIfNeeded prompts once while blocked`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = false
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        model.promptIfNeeded()
        #expect(trust.requestTrustCallCount == 1)
        #expect(model.hasPrompted == true)
    }

    @Test
    func `promptIfNeeded does not prompt again on a later call`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = false
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        model.promptIfNeeded()
        model.promptIfNeeded()
        #expect(trust.requestTrustCallCount == 1)
    }

    @Test
    func `promptIfNeeded does not prompt again after a later refresh finds it still blocked`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = false
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        model.promptIfNeeded()
        model.refresh()
        model.promptIfNeeded()
        #expect(trust.requestTrustCallCount == 1)
    }

    @Test
    func `promptIfNeeded does nothing while ready`() {
        let trust = FakeAccessibilityTrustChecking()
        trust.isTrusted = true
        let model = AccessibilityGateViewModel(trust: trust)
        model.refresh()
        model.promptIfNeeded()
        #expect(trust.requestTrustCallCount == 0)
        #expect(model.hasPrompted == false)
    }
}
