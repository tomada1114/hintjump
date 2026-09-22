import Foundation
@testable import HintjumpCore
import Testing

/// The fake every Core test of ``FrontmostAppObserving`` uses: a real observer whose
/// "app switches" are whatever the test announces with ``activate(_:)``
/// (`.claude/rules/testing.md` › Fakes, not mocks).
///
/// `@MainActor`, like the port, which is what makes it `Sendable` without an
/// `@unchecked` of its own.
@MainActor
final class FakeFrontmostAppObserver: FrontmostAppObserving {
    /// How many times ``stopObserving()`` was called.
    private(set) var stopCount = 0
    private var handler: (@MainActor (FrontmostApp) -> Void)?

    /// Whether a handler is installed right now.
    var isObserving: Bool {
        handler != nil
    }

    func startObserving(_ handler: @escaping @MainActor (FrontmostApp) -> Void) {
        self.handler = handler
    }

    func stopObserving() {
        stopCount += 1
        handler = nil
    }

    /// Announces that `app` became frontmost, as the OS would — to nobody when nothing
    /// is observing.
    func activate(_ app: FrontmostApp) {
        handler?(app)
    }
}

/// Which app the triggers are off in, and which app the status menu names — against
/// the fake observer and the fake registrar.
@MainActor
@Suite("DisabledAppsPolicy")
struct DisabledAppsPolicyTests {
    /// The pieces one test drives: a policy started over the default triggers, with
    /// `disabled` as the configuration's disabled apps.
    struct Harness {
        let registrar: FakeTriggerRegistrar
        let controller: TriggerController
        let observer: FakeFrontmostAppObserver
        let policy: DisabledAppsPolicy
    }

    static let textEdit = FrontmostApp(
        name: "TextEdit",
        bundleIdentifier: "com.apple.TextEdit",
        processIdentifier: 501,
    )
    static let finder = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: 502,
    )
    static let noBundle = FrontmostApp(name: "helper", processIdentifier: 503)
    /// This test process, standing in for Hintjump itself.
    static let ownProcess = FrontmostApp(
        name: "Hintjump",
        bundleIdentifier: "io.github.tomada1114.Hintjump",
        processIdentifier: ProcessInfo.processInfo.processIdentifier,
    )

    static func harness(disabled: [String]) -> Harness {
        var config = HintjumpConfig.default
        config.disabledApps = disabled
        let frozen = config
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.apply(frozen)
        let observer = FakeFrontmostAppObserver()
        let policy = DisabledAppsPolicy(controller: controller, observer: observer) { frozen }
        return Harness(
            registrar: registrar,
            controller: controller,
            observer: observer,
            policy: policy,
        )
    }

    @Test
    func `start with a disabled app frontmost suspends the triggers at once`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])

        harness.policy.start(from: Self.textEdit)

        #expect(harness.controller.isSuspended)
        #expect(harness.registrar.registered.isEmpty)
        #expect(harness.policy.lastExternalApp == Self.textEdit)
        #expect(harness.policy.isLastExternalAppDisabled)
        #expect(harness.observer.isObserving)
    }

    @Test
    func `start with no frontmost app observes and changes nothing`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])

        harness.policy.start(from: nil)

        #expect(!harness.controller.isSuspended)
        #expect(harness.registrar.registered.count == EntryPoint.allCases.count)
        #expect(harness.policy.lastExternalApp == nil)
        #expect(harness.observer.isObserving)
    }

    @Test
    func `activating a disabled app suspends, and activating another resumes`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])
        harness.policy.start(from: Self.finder)
        #expect(harness.registrar.registered.count == EntryPoint.allCases.count)

        harness.observer.activate(Self.textEdit)

        #expect(harness.controller.isSuspended)
        #expect(harness.registrar.registered.isEmpty)

        harness.observer.activate(Self.finder)

        #expect(!harness.controller.isSuspended)
        #expect(harness.registrar.registered == TriggerControllerTests.defaultBindings)
        #expect(harness.policy.lastExternalApp == Self.finder)
        #expect(!harness.policy.isLastExternalAppDisabled)
    }

    @Test
    func `activating this process changes neither the suspension nor the last app`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])
        harness.policy.start(from: Self.textEdit)

        harness.observer.activate(Self.ownProcess)

        #expect(harness.controller.isSuspended)
        #expect(harness.policy.lastExternalApp == Self.textEdit)
        #expect(harness.policy.isLastExternalAppDisabled)
    }

    @Test
    func `an app with no bundle identifier is never disabled, but is the last app`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])
        harness.policy.start(from: Self.textEdit)

        harness.observer.activate(Self.noBundle)

        #expect(!harness.controller.isSuspended)
        #expect(harness.policy.lastExternalApp == Self.noBundle)
        #expect(!harness.policy.isLastExternalAppDisabled)
    }

    @Test
    func `a second activation of the same disabled app unregisters nothing more`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])
        harness.policy.start(from: Self.textEdit)
        let calls = harness.registrar.calls

        harness.observer.activate(Self.textEdit)

        #expect(harness.registrar.calls == calls)
        #expect(harness.controller.isSuspended)
    }

    @Test
    func `reevaluate before any app was seen does nothing`() {
        let harness = Self.harness(disabled: [])

        harness.policy.reevaluate()

        #expect(!harness.controller.isSuspended)
        #expect(harness.registrar.calls == ["unregisterAll", "register"])
    }

    @Test
    func `stop stops observing, so a later switch changes nothing`() {
        let harness = Self.harness(disabled: ["com.apple.TextEdit"])
        harness.policy.start(from: Self.finder)

        harness.policy.stop()
        harness.observer.activate(Self.textEdit)

        #expect(harness.observer.stopCount == 1)
        #expect(!harness.observer.isObserving)
        #expect(!harness.controller.isSuspended)
        #expect(harness.policy.lastExternalApp == Self.finder)
    }
}
