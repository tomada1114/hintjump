/// Makes the login item match `[startup] launch_at_login`.
///
/// The decision behind ``LoginItemRegistering``: change the registration only when it
/// disagrees with the key, and never let a refusal escape. ``ConfigStore`` runs it after
/// every successful load, so a reload is what applies an edit to the key.
@MainActor
struct LoginItemSync {
    /// What one ``apply(launchAtLogin:)`` did — returned so a test can assert on it
    /// rather than on a log line.
    enum Outcome: Equatable {
        /// The registration already matched, so the OS was not asked to change it.
        case unchanged
        /// The app was registered as a login item.
        case registered
        /// The app was unregistered as a login item.
        case unregistered
        /// The OS refused the change; the registration is whatever it was before.
        case failed(LoginItemError)
    }

    private let loginItem: any LoginItemRegistering

    init(loginItem: any LoginItemRegistering) {
        self.loginItem = loginItem
    }

    /// Registers or unregisters so the login item matches `launchAtLogin`, and logs
    /// what happened.
    ///
    /// Reads first and changes only on a mismatch: registering an app that is already
    /// registered is not free — the OS may post its "added a login item" notification
    /// again — and every reload would otherwise do it.
    ///
    /// A failure is logged and reported, never thrown: the configuration was read
    /// fine, so the reload that asked for this succeeded, and the next one retries.
    @discardableResult
    func apply(launchAtLogin: Bool) -> Outcome {
        guard loginItem.isRegistered != launchAtLogin else {
            AppLog.config.debug("login item: unchanged")
            return .unchanged
        }
        do {
            try loginItem.setRegistered(launchAtLogin)
        } catch {
            let what = launchAtLogin ? "failed to register" : "failed to unregister"
            let code = error.code
            let reason = error.reason
            AppLog.config.error(
                "login item: \(what, privacy: .public), code \(code, privacy: .public): \(reason, privacy: .private)",
            )
            return .failed(error)
        }
        let outcome: Outcome = launchAtLogin ? .registered : .unregistered
        AppLog.config.info(
            "login item: \(launchAtLogin ? "registered" : "unregistered", privacy: .public)",
        )
        return outcome
    }
}
