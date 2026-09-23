import HintjumpCore
import HintjumpPlatform
import HintjumpUI
import SwiftUI

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
    /// The one apply path: every writer of the configuration hands what ``store``
    /// adopted to it, so the triggers and ``disabledApps`` follow.
    let applier: ConfigApplier
    /// What the status menu's "Open Config File", "Reload Config", and
    /// "Disable in <App>" do.
    let statusMenu: StatusMenuModel
    /// The hint session every trigger press is handed to.
    let hints: HintSession
    /// Whether this process holds the Accessibility grant. Composed once, here, rather
    /// than inside a view: it must survive scene recreation and keep its own
    /// `hasPrompted` state for the life of the process, and the status item's gate and
    /// the Settings window read the same one.
    let accessibilityGate: AccessibilityGateViewModel
    /// The Settings window's model, kept for the life of the process so the selected
    /// pane survives the window closing.
    let settings: SettingsViewModel

    init() {
        let configStore = ConfigStore(file: UserConfigFile(), loginItem: SMAppServiceLoginItem())
        store = configStore
        triggers = TriggerController(registrar: CarbonTriggerRegistrar())
        disabledApps = DisabledAppsPolicy(
            controller: triggers,
            observer: WorkspaceFrontmostAppObserver(),
        ) { configStore.config }
        applier = ConfigApplier(store: configStore, controller: triggers, policy: disabledApps)
        statusMenu = StatusMenuModel(
            store: configStore,
            applier: applier,
            opener: WorkspaceConfigFileOpener(),
            policy: disabledApps,
        )
        let gate = AccessibilityGateViewModel(trust: SystemAccessibilityTrust())
        accessibilityGate = gate
        settings = SettingsViewModel(
            store: configStore,
            applier: applier,
            gate: gate,
            system: SettingsSystem(
                ports: SettingsPorts(
                    systemSettings: WorkspaceSystemSettingsOpener(),
                    configFile: WorkspaceConfigFileOpener(),
                    pasteboard: GeneralPasteboardWriter(),
                ),
                version: AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:]),
                homeDirectory: NSHomeDirectory(),
            ),
        )
        hints = Self.makeHintSession { configStore.config }
        // The controller logs every press before handing it on, so a press stays
        // observable even when the session shows nothing for it.
        triggers.onTrigger = { [hints] entryPoint in
            hints.trigger(entryPoint)
        }
    }

    /// The hint session over the real adapters, with the overlay panel's content — the
    /// view that renders the session — installed.
    ///
    /// One `WindowTargetCollector` serves both frontmost-window entry points, so they
    /// share its memory of which apps needed waking; `SystemTopmostContainerProbe` tells
    /// it what is on top of the frontmost window. The status items come from the
    /// window list instead (`WindowListStatusItems`). An entry point with no collector
    /// yet is logged by the session as not available.
    private static func makeHintSession(
        configuration: @escaping @MainActor () -> HintjumpConfig,
    ) -> HintSession {
        let presenter = PanelHintOverlayPresenter()
        let windowCollector = WindowTargetCollector(
            reader: AXUIElementTreeReader(),
            probe: SystemTopmostContainerProbe(),
        )
        let session = HintSession(
            frontmostApp: WorkspaceFrontmostAppProvider(),
            collectors: [
                .clickInWindow: windowCollector,
                .rightClickInWindow: windowCollector,
                .appMenus: AppMenuTargetCollector(reader: AXUIElementTreeReader()),
                .statusIcons: StatusItemTargetCollector(listing: WindowListStatusItems()),
            ],
            presenter: presenter,
            clicker: CGEventClickPerformer(),
            configuration: configuration,
        )
        let hostingView = NSHostingView(rootView: HintOverlayView(session: session))
        // The panel's frame is the canvas the session chose; the view must never resize it.
        hostingView.sizingOptions = []
        presenter.install(contentView: hostingView)
        return session
    }

    /// Loads the config file, registers the triggers it names, then starts following
    /// app switches from the app frontmost now — suspending the triggers at once if that
    /// app is disabled.
    ///
    /// A failed load is logged by the store and leaves the defaults in force, so the
    /// triggers are registered either way. Every step is idempotent — a second load
    /// re-reads the same file, ``ConfigApplier/apply()`` starts the triggers from
    /// nothing, and a second start replaces the observer — so a second call, from a
    /// label that appeared twice, needs no started-flag.
    func start() {
        _ = try? store.load()
        applier.apply()
        disabledApps.start(from: WorkspaceFrontmostAppProvider().currentFrontmostApp())
    }
}
