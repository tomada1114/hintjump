import Foundation
import Observation

/// Turns the four triggers off while an app in `[apps] disabled` is frontmost, and
/// remembers which app the status menu's "Disable in <App>" item names.
///
/// "Off" means unregistered, not ignored: a Carbon hotkey consumes its key combination
/// for every app, so a press that is swallowed and then ignored would still never reach
/// the app the user disabled Hintjump in. All four go, the menu-bar triggers included,
/// because the usual reason to disable is a shortcut collision, and that applies to
/// every one of them (`docs/decisions.md` › "A disabled app gets every trigger key
/// back").
///
/// `@Observable` so the status menu's item title follows ``lastExternalApp`` and
/// ``isLastExternalAppDisabled`` without a second source of truth.
@MainActor
@Observable
public final class DisabledAppsPolicy {
    /// The last app to become frontmost that is not this process — what the menu item
    /// names. Opening Hintjump's own menu can make Hintjump frontmost, and that must not
    /// make Hintjump the subject of "Disable in <App>", so this process is skipped.
    public private(set) var lastExternalApp: FrontmostApp?
    /// Whether ``lastExternalApp`` is in the configuration's disabled list, as of the
    /// last evaluation. Stored rather than computed from the configuration so an
    /// observer of this object sees the change a toggle or a reload makes.
    public private(set) var isLastExternalAppDisabled = false

    @ObservationIgnored private let controller: TriggerController
    @ObservationIgnored private let observer: any FrontmostAppObserving
    @ObservationIgnored private let configuration: @MainActor () -> HintjumpConfig

    /// - Parameter configuration: Read on every evaluation, so a reload or a toggle is
    ///   seen by the next one without this object holding a copy.
    public init(
        controller: TriggerController,
        observer: any FrontmostAppObserving,
        configuration: @escaping @MainActor () -> HintjumpConfig,
    ) {
        self.controller = controller
        self.observer = observer
        self.configuration = configuration
    }

    /// Starts following app switches, then evaluates `current` — the app frontmost at
    /// launch, which no switch notification will ever announce.
    public func start(from current: FrontmostApp?) {
        observer.startObserving { [weak self] app in
            self?.evaluate(app)
        }
        if let current {
            evaluate(current)
        }
    }

    /// Stops following app switches; the triggers stay as they are.
    public func stop() {
        observer.stopObserving()
    }

    /// `app` became frontmost: remember it, unless it is this process, and suspend or
    /// resume the triggers to match it.
    public func evaluate(_ app: FrontmostApp) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        lastExternalApp = app
        reevaluate()
    }

    /// Suspends or resumes the triggers for ``lastExternalApp`` against the
    /// configuration as it is now — what a toggle and a reload call, since either can
    /// change the list without any app switching.
    ///
    /// Only a change is acted on and logged, so a second activation of the same app is
    /// silent. The bundle identifier is `.private`: which apps someone uses is theirs.
    public func reevaluate() {
        guard let app = lastExternalApp else {
            return
        }
        let bundleID = app.bundleIdentifier ?? ""
        let disabled = app.bundleIdentifier.map(configuration().disabledApps.contains) ?? false
        isLastExternalAppDisabled = disabled
        guard disabled != controller.isSuspended else {
            return
        }
        controller.setSuspended(disabled)
        if disabled {
            AppLog.triggers.info(
                "triggers suspended: disabled app frontmost app=\(bundleID, privacy: .private)",
            )
        } else {
            AppLog.triggers.info("triggers resumed app=\(bundleID, privacy: .private)")
        }
    }
}
