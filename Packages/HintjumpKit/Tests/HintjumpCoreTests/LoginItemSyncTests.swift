@testable import HintjumpCore
import Testing

/// The fake every Core test of ``LoginItemRegistering`` uses: a real, working login
/// item backed by a Bool, which records every change it was asked for
/// (`.claude/rules/testing.md` › Fakes, not mocks).
///
/// `@MainActor`, like the port, which is what makes it `Sendable` without an
/// `@unchecked` of its own.
@MainActor
final class FakeLoginItem: LoginItemRegistering {
    /// Whether the fake is registered right now; a successful change flips it.
    var isRegistered: Bool
    /// Set to have every change fail with this error, leaving ``isRegistered`` alone.
    var setError: LoginItemError?
    /// Every value handed to ``setRegistered(_:)``, in order — including failed ones.
    private(set) var setCalls: [Bool] = []

    init(isRegistered: Bool) {
        self.isRegistered = isRegistered
    }

    func setRegistered(_ enabled: Bool) throws(LoginItemError) {
        setCalls.append(enabled)
        if let setError {
            throw setError
        }
        isRegistered = enabled
    }
}

/// An error the fake can fail a change with; the payload is arbitrary but fixed.
let fakeLoginItemError = LoginItemError(code: 1, reason: "Operation not permitted")

/// Making the login item match `launch_at_login` — the decision, against the fake.
@MainActor
@Suite("LoginItemSync")
struct LoginItemSyncTests {
    @Test(arguments: [true, false])
    func `leaves a login item that already matches untouched`(_ enabled: Bool) {
        let loginItem = FakeLoginItem(isRegistered: enabled)

        let outcome = LoginItemSync(loginItem: loginItem).apply(launchAtLogin: enabled)

        #expect(outcome == .unchanged)
        #expect(loginItem.setCalls.isEmpty)
    }

    @Test
    func `registers when the key is on and the item is not`() {
        let loginItem = FakeLoginItem(isRegistered: false)

        let outcome = LoginItemSync(loginItem: loginItem).apply(launchAtLogin: true)

        #expect(outcome == .registered)
        #expect(loginItem.setCalls == [true])
        #expect(loginItem.isRegistered)
    }

    @Test
    func `unregisters when the key is off and the item is registered`() {
        let loginItem = FakeLoginItem(isRegistered: true)

        let outcome = LoginItemSync(loginItem: loginItem).apply(launchAtLogin: false)

        #expect(outcome == .unregistered)
        #expect(loginItem.setCalls == [false])
        #expect(loginItem.isRegistered == false)
    }

    @Test(arguments: [true, false])
    func `reports a failed change with the port's error`(_ enabled: Bool) {
        let loginItem = FakeLoginItem(isRegistered: !enabled)
        loginItem.setError = fakeLoginItemError

        let outcome = LoginItemSync(loginItem: loginItem).apply(launchAtLogin: enabled)

        #expect(outcome == .failed(fakeLoginItemError))
        #expect(loginItem.setCalls == [enabled])
        #expect(loginItem.isRegistered == !enabled)
    }

    @Test
    func `applying twice changes the item once`() {
        let loginItem = FakeLoginItem(isRegistered: false)
        let sync = LoginItemSync(loginItem: loginItem)

        #expect(sync.apply(launchAtLogin: true) == .registered)
        #expect(sync.apply(launchAtLogin: true) == .unchanged)
        #expect(loginItem.setCalls == [true])
    }

    @Test
    func `a failed change is retried on the next apply`() {
        let loginItem = FakeLoginItem(isRegistered: false)
        loginItem.setError = fakeLoginItemError
        let sync = LoginItemSync(loginItem: loginItem)

        #expect(sync.apply(launchAtLogin: true) == .failed(fakeLoginItemError))
        loginItem.setError = nil

        #expect(sync.apply(launchAtLogin: true) == .registered)
        #expect(loginItem.setCalls == [true, true])
    }

    @Test
    func `the error carries its code and reason`() {
        let error = LoginItemError(code: 3, reason: "Invalid signature")

        #expect(error.code == 3)
        #expect(error.reason == "Invalid signature")
        #expect(error != fakeLoginItemError)
    }
}
