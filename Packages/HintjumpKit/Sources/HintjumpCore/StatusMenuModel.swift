/// What the status menu's items do: open the config file, re-read and apply it, and
/// disable or enable Hintjump in the last app that was frontmost.
///
/// A Core type rather than closures in `App/` because "a failed reload leaves the
/// triggers alone" and "which app the item names" are decisions, and a decision belongs
/// where the coverage floor sees it. Every item that adopts a configuration then hands
/// it to ``ConfigApplier``, the one apply path, rather than applying pieces of it here.
@MainActor
public final class StatusMenuModel {
    private let store: ConfigStore
    private let applier: ConfigApplier
    private let opener: any ConfigFileOpening
    private let policy: DisabledAppsPolicy

    /// The per-app item's title: "Disable in <App>" for the last app frontmost other
    /// than Hintjump, "Enable in <App>" when that app is already disabled, and `nil` —
    /// no item — when there is no such app or it has no bundle identifier to list.
    ///
    /// Reads only the policy's observable state, so a menu showing it updates when a
    /// switch, a toggle, or a reload changes either.
    public var disableItemTitle: String? {
        guard let app = policy.lastExternalApp, app.bundleIdentifier != nil else {
            return nil
        }
        return policy.isLastExternalAppDisabled ? "Enable in \(app.name)" : "Disable in \(app.name)"
    }

    /// Takes the same store, applier, and policy `App/` starts with, so a reload
    /// re-reads the file launch read and re-registers the triggers launch registered.
    public init(
        store: ConfigStore,
        applier: ConfigApplier,
        opener: any ConfigFileOpening,
        policy: DisabledAppsPolicy,
    ) {
        self.store = store
        self.applier = applier
        self.opener = opener
        self.policy = policy
    }

    /// "Open Config File": opens the file the store reads.
    public func openConfigFile() {
        opener.open(path: store.path)
    }

    /// "Reload Config": re-reads the file and, only if it parsed, applies it
    /// (``ConfigApplier/apply()``).
    ///
    /// A failure leaves the registered triggers exactly as they are — the store keeps
    /// the last good configuration, and the shortcuts should keep matching it while the
    /// user fixes the file. A ``ConfigError``'s message is logged `.public`: it names a
    /// line and a key of the app's own file, which is what the person reading the log
    /// needs to see. Any other failure is an I/O error whose text can carry a path, so
    /// it stays `.private`.
    public func reloadConfig() {
        do {
            try store.reload()
        } catch let error as ConfigError {
            AppLog.config.error("config reload failed: \(error.message, privacy: .public)")
            return
        } catch {
            AppLog.config
                .error("config reload failed: \(String(describing: error), privacy: .private)")
            return
        }
        AppLog.config.info("config reloaded")
        applier.apply()
    }

    /// "Disable in <App>" / "Enable in <App>": adds the last app to `[apps] disabled`, or
    /// removes it, and suspends or resumes the triggers at once.
    ///
    /// The write goes through ``ConfigStore/setDisabled(_:_:)``, which rewrites only
    /// that list, and what it adopted is then applied. A file that does not parse is not
    /// written over: the failure is logged — a ``ConfigError``'s message `.public`, as
    /// on a reload — and nothing changes.
    public func toggleDisabledForLastApp() {
        guard let bundleID = policy.lastExternalApp?.bundleIdentifier else {
            return
        }
        let disable = !policy.isLastExternalAppDisabled
        do {
            try store.setDisabled(bundleID, disable)
        } catch let error as ConfigError {
            AppLog.config.error("disabled apps not changed: \(error.message, privacy: .public)")
            return
        } catch {
            AppLog.config.error(
                "disabled apps not changed: \(String(describing: error), privacy: .private)",
            )
            return
        }
        AppLog.config.info(
            "\(disable ? "disabled" : "enabled", privacy: .public) in app=\(bundleID, privacy: .private)",
        )
        applier.apply()
    }
}
