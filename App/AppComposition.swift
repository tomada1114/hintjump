import HintjumpCore
import HintjumpPlatform

/// The composition root: the one place that knows both halves of every port.
///
/// It constructs the `HintjumpPlatform` adapters and hands them to the `HintjumpCore`
/// types that decide, so nothing below `App/` depends on which implementation answers
/// (`docs/architecture.md` › Layers). An object rather than more `@State` in
/// `HintjumpApp`, so the app struct stays wiring for scenes and this stays wiring for
/// everything behind them.
@MainActor
final class AppComposition {
    /// The config file, read at ``start()`` and on "Reload Config"; every successful
    /// load also applies `launch_at_login`.
    let store: ConfigStore
    /// The four global shortcuts, registered from ``store``'s configuration.
    let triggers: TriggerController
    /// Unregisters the triggers while an app in `[apps] disabled` is frontmost, following
    /// every app switch.
    let disabledApps: DisabledAppsPolicy
    /// What the status menu's "Open Config File", "Reload Config", and
    /// "Disable in <App>" do.
    let statusMenu: StatusMenuModel

    init() {
        let configStore = ConfigStore(file: UserConfigFile(), loginItem: SMAppServiceLoginItem())
        store = configStore
        triggers = TriggerController(registrar: CarbonTriggerRegistrar())
        disabledApps = DisabledAppsPolicy(
            controller: triggers,
            observer: WorkspaceFrontmostAppObserver(),
        ) { configStore.config }
        statusMenu = StatusMenuModel(
            store: store,
            controller: triggers,
            opener: WorkspaceConfigFileOpener(),
            policy: disabledApps,
        )
        // `triggers.onTrigger` stays nil until the hint session exists: the controller
        // logs every press on its own, so a trigger is observable before it does anything.
    }

    /// Loads the config file, registers the triggers it names, then starts following
    /// app switches from the app frontmost now — suspending the triggers at once if that
    /// app is disabled.
    ///
    /// A failed load is logged by the store and leaves the defaults in force, so the
    /// triggers are registered either way. Every step is idempotent — a second load
    /// re-reads the same file, ``TriggerController/apply(_:)`` starts from nothing, and a
    /// second start replaces the observer — so a second call, from a label that appeared
    /// twice, needs no started-flag.
    func start() {
        _ = try? store.load()
        triggers.apply(store.config)
        disabledApps.start(from: WorkspaceFrontmostAppProvider().currentFrontmostApp())
    }
}
