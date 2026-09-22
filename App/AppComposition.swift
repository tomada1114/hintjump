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
    /// What the status menu's "Open Config File" and "Reload Config" do.
    let statusMenu: StatusMenuModel
    /// The hint session every trigger press is handed to.
    let hints: HintSession

    init() {
        let configStore = ConfigStore(file: UserConfigFile(), loginItem: SMAppServiceLoginItem())
        store = configStore
        triggers = TriggerController(registrar: CarbonTriggerRegistrar())
        statusMenu = StatusMenuModel(
            store: configStore,
            controller: triggers,
            opener: WorkspaceConfigFileOpener(),
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
    /// share its memory of which apps needed waking. The menu-bar entry points have no
    /// collector yet, and the session logs a press of one as not available.
    private static func makeHintSession(
        configuration: @escaping @MainActor () -> HintjumpConfig,
    ) -> HintSession {
        let presenter = PanelHintOverlayPresenter()
        let windowCollector = WindowTargetCollector(reader: AXUIElementTreeReader())
        let session = HintSession(
            frontmostApp: WorkspaceFrontmostAppProvider(),
            collectors: [.clickInWindow: windowCollector, .rightClickInWindow: windowCollector],
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

    /// Loads the config file, then registers the triggers it names.
    ///
    /// A failed load is logged by the store and leaves the defaults in force, so the
    /// triggers are registered either way. Both steps are idempotent — a second load
    /// re-reads the same file, and ``TriggerController/apply(_:)`` starts from nothing —
    /// so a second call, from a label that appeared twice, needs no started-flag.
    func start() {
        _ = try? store.load()
        triggers.apply(store.config)
    }
}
