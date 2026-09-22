/// A port: is this app registered to open at login, and make it so (or not).
///
/// `SMAppService.mainApp` answers both halves, but it lives in `ServiceManagement`, which
/// Core may not import (`docs/architecture.md` › Layers), so the adapter in
/// `HintjumpPlatform` translates and ``LoginItemSync`` decides. `@MainActor` because the
/// only caller, ``ConfigStore``, is, and because it keeps a class-backed fake `Sendable`
/// without an `@unchecked` of its own.
@MainActor
public protocol LoginItemRegistering: Sendable {
    /// Whether the app is registered as a login item right now.
    ///
    /// Registered but switched off by the user in System Settings › General › Login
    /// Items still counts as registered: that switch is the user's, and a config
    /// reload that silently re-registered over it would take it away from them.
    var isRegistered: Bool { get }

    /// Registers the app as a login item, or unregisters it.
    ///
    /// Typed so the adapter has to translate whatever the OS threw into a value Core
    /// owns, rather than leaking an `NSError` from a framework Core cannot import.
    func setRegistered(_ enabled: Bool) throws(LoginItemError)
}
