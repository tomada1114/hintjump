/// What the status menu's config items do: open the file, and re-read and apply it.
///
/// A Core type rather than two closures in `App/` because "a failed reload leaves the
/// triggers alone" is a decision, and a decision belongs where the coverage floor sees
/// it. There is one reload path: ``ConfigStore/reload()`` already applies
/// `launch_at_login`, and this adds the triggers on top of it.
@MainActor
public final class StatusMenuModel {
    private let store: ConfigStore
    private let controller: TriggerController
    private let opener: any ConfigFileOpening

    /// Takes the same store and controller `App/` starts with, so a reload re-reads the
    /// file launch read and re-registers the triggers launch registered.
    public init(store: ConfigStore, controller: TriggerController, opener: any ConfigFileOpening) {
        self.store = store
        self.controller = controller
        self.opener = opener
    }

    /// "Open Config File": opens the file the store reads.
    public func openConfigFile() {
        opener.open(path: store.path)
    }

    /// "Reload Config": re-reads the file and, only if it parsed, re-registers the
    /// triggers from it.
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
        controller.apply(store.config)
    }
}
