/// The one path from "a configuration was adopted" to "it is in force".
///
/// Every writer of the configuration — the status menu's reload and "Disable in <App>",
/// the Settings window, a file watcher — adopts through ``ConfigStore`` and then calls
/// ``apply()``, so none of them repeats the sequence or forgets a step of it.
/// `launch_at_login` is not repeated here: the store applies it as part of every
/// adoption, because only the store knows whether the file parsed, and a file that did
/// not must leave the login item alone. What is left is the triggers, then the
/// disabled-apps policy, in that order: the policy suspends the triggers just
/// registered when the frontmost app is disabled, and a resume registers what the
/// controller was last handed.
@MainActor
public struct ConfigApplier {
    private let store: ConfigStore
    private let controller: TriggerController
    private let policy: DisabledAppsPolicy

    /// Takes the same store, controller, and policy `App/` starts with, so an apply
    /// registers what the store adopted, on the controller the policy suspends.
    public init(store: ConfigStore, controller: TriggerController, policy: DisabledAppsPolicy) {
        self.store = store
        self.controller = controller
        self.policy = policy
    }

    /// Re-registers the triggers from the store's configuration and re-evaluates the
    /// disabled-apps policy against it.
    ///
    /// Reads ``ConfigStore/config`` rather than taking a configuration, so the triggers
    /// and the policy — which reads the store too — can never be handed two different
    /// ones. A failed reload has no reason to call it — the store still holds the last
    /// good configuration, which is already in force — while launch calls it either way,
    /// so a file that fails to load still leaves the default triggers registered.
    public func apply() {
        controller.apply(store.config)
        policy.reevaluate()
    }
}
