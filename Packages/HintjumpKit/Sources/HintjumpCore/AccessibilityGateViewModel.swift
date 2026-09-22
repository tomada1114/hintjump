import Observation

/// Observable presentation state over an ``AccessibilityTrustChecking`` port.
///
/// The Core half of the trust check, copied from `.agents/skills/integrating-system-apis/
/// references/tcc-permissions.md` › "Degraded, not broken": `state`, whether the prompt
/// has been spent, and when to spend it are all decisions, so they all live here, behind
/// the port, where `HintjumpCoreTests` drives them with a fake and the coverage floor sees
/// them. The adapter in `HintjumpPlatform` holds no branching logic of its own.
@MainActor
@Observable
public final class AccessibilityGateViewModel {
    /// Whether the app currently holds the Accessibility grant, as far as the last
    /// ``refresh()`` could tell.
    public enum State: Equatable, Sendable {
        /// Before the first ``refresh()``.
        case unknown
        /// The grant is not held.
        case blocked
        /// The grant is held.
        case ready
    }

    /// The last answer ``refresh()`` got from the port.
    public private(set) var state: State = .unknown

    /// Whether ``promptIfNeeded()`` has already shown the system prompt this process.
    ///
    /// macOS shows its Accessibility prompt at most once per app regardless of how many
    /// times it is asked, so tracking this here keeps a second call from training the
    /// user to ignore a prompt that will not reappear.
    public private(set) var hasPrompted = false

    private let trust: any AccessibilityTrustChecking

    /// Creates the view model over `trust`. Asking the OS in an initializer would make
    /// construction a side effect, so nothing is read until ``refresh()``.
    public init(trust: any AccessibilityTrustChecking) {
        self.trust = trust
    }

    /// Asks the port again and publishes what it answered.
    ///
    /// Call at launch and every time the app becomes active: the user grants the
    /// permission in another process (System Settings), and returning to the foreground
    /// is the only signal this app gets that something may have changed
    /// (`tcc-permissions.md` › "The grant arrives with no callback").
    ///
    /// Also the worked example of a log call for a state that is safe to log in the
    /// clear: which of `ready`/`blocked` this process is in reveals nothing about the
    /// user's data, so it is logged `.public`.
    public func refresh() {
        let newState: State = trust.isTrusted ? .ready : .blocked
        state = newState
        AppLog.permissions.debug(
            "accessibility trust: \(newState == .ready ? "ready" : "blocked", privacy: .public)",
        )
    }

    /// Shows the system prompt, but only while ``state`` is ``State/blocked`` and only
    /// once per process.
    ///
    /// The reference explains why the prompt is spent at the moment the user first
    /// reaches for the feature that needs it: for a menu-bar agent whose only feature
    /// needs the Accessibility grant, that moment is launch, so the app calls this once
    /// there rather than waiting for a deeper interaction that never comes.
    public func promptIfNeeded() {
        guard state == .blocked, !hasPrompted else {
            return
        }
        hasPrompted = true
        trust.requestTrust()
    }
}
