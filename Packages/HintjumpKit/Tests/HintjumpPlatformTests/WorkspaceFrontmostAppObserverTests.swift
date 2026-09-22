import AppKit
import HintjumpCore
import HintjumpPlatform
import Testing

/// `WorkspaceFrontmostAppObserver` against the real `NSWorkspace` notification center.
///
/// What a Core test with the fake cannot ask: does the adapter really observe the
/// center `NSWorkspace` posts activations on, find the `NSRunningApplication` under
/// `applicationUserInfoKey`, and hand on a `FrontmostApp` with a pid — and does
/// `stopObserving()` really stop it? What an activation *means* stays a Core test of
/// `DisabledAppsPolicy` against `FakeFrontmostAppObserver`.
///
/// Needs no TCC grant, and activates nothing: it posts the activation itself, inside
/// this test process, carrying the already-running Finder's `NSRunningApplication` — so
/// no app's activation changes and the user's frontmost app stays where it is. That the
/// OS posts the notification on a real switch is `NSWorkspace`'s documented contract;
/// the running app's `triggers suspended` / `triggers resumed` log lines are the
/// evidence for it. Finder rather than this process because a command-line test runner
/// has no `localizedName`, and the adapter drops such an app by design.
@Suite("WorkspaceFrontmostAppObserver against the real NSWorkspace", .requiresLocalMachine)
@MainActor
struct WorkspaceFrontmostAppObserverTests {
    /// How long to wait for a notification before concluding none is coming.
    static let timeout: Duration = .seconds(3)

    /// Waits, yielding the main actor so `OperationQueue.main` can deliver, until
    /// `received` holds an app or ``timeout`` passes.
    static func waitForDelivery(_ received: () -> [FrontmostApp]) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while received().isEmpty, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Posts, on the workspace center, the notification the OS posts when `application`
    /// becomes frontmost — delivered to this process's observers only.
    static func postActivation(of application: NSRunningApplication) {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: application],
        )
    }

    @Test
    func `translates an activation on the workspace center, and stops when told`() async throws {
        let finder = try LocalMachineTests.require(
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                .first,
            requires: "a logged-in GUI session, where Finder is always running",
            grant: false,
        )
        let observer = WorkspaceFrontmostAppObserver()
        var received: [FrontmostApp] = []
        observer.startObserving { received.append($0) }
        defer { observer.stopObserving() }

        Self.postActivation(of: finder)
        try await Self.waitForDelivery { received }

        let expected = FrontmostApp(
            name: finder.localizedName ?? "",
            bundleIdentifier: "com.apple.finder",
            processIdentifier: finder.processIdentifier,
        )
        #expect(received == [expected])

        observer.stopObserving()
        observer.stopObserving()
        Self.postActivation(of: finder)
        try await Task.sleep(for: .milliseconds(200))

        #expect(received.count == 1)
    }
}
