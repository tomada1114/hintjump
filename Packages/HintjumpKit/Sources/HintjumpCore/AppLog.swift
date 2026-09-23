import os

/// This app's unified-log entry point: one subsystem, one `Logger` per concern.
///
/// `HintjumpCore` is allowed to `import os`. The Core ban list holds UI frameworks and the
/// OS-integration frameworks an adapter reaches for; `os` is neither — it is Apple's
/// logging facility, it pulls in no AppKit, and it works unchanged on every platform
/// Core is meant to serve, so keeping logging behind a port would buy nothing and cost
/// every call site an injection (`docs/architecture.md` › Logging). `HintjumpUI`,
/// `HintjumpPlatform`, and `App/` log through these same loggers, which they already see
/// by importing `HintjumpCore`.
///
/// Never `print`, `debugPrint`, or `NSLog` under `Sources/` or `App/`: a `.app` launched
/// the way users launch it has nowhere to send stdout, so those lines vanish exactly
/// when they would matter. `.swiftlint.yml`'s `no_print_in_sources` rejects them.
/// Anything user-derived that reaches a log message carries a privacy annotation —
/// see ``FrontmostAppViewModel/refresh()`` for the worked example.
public enum AppLog {
    /// The subsystem every logger below is created with: this app's bundle identifier,
    /// and the value `just logs` filters the stream on.
    ///
    /// A literal rather than `Bundle.main.bundleIdentifier`, which answers for the test
    /// runner under `swift test` and for the preview agent in an Xcode preview — log
    /// lines would scatter across subsystems nothing is watching. It is spelled here
    /// once and nowhere else in Swift; `scripts/bootstrap.sh` rewrites it with the same
    /// placeholder replacement that rewrites `project.yml`, and `AppLogTests` fails if
    /// the two ever disagree.
    public static let subsystem = "io.github.tomada1114.Hintjump"

    /// The frontmost-application concern: ``FrontmostAppProviding`` and its view model.
    ///
    /// One category per concern, named for the concern rather than for a type, so
    /// `log stream --predicate 'category == "frontmost-app"'` narrows the stream to one
    /// story. A new concern adds a `Logger` here instead of building one inline.
    public static let frontmostApp = Logger(subsystem: subsystem, category: "frontmost-app")

    /// The accessibility concern: ``AccessibilityTreeReading`` and the adapter that
    /// reads another application's tree.
    ///
    /// Its own category because the story it tells is a different one — a read of a
    /// foreign process, its size, and what it cost — and because that stream is the one
    /// a read-latency investigation watches: `log stream --predicate 'category ==
    /// "accessibility"'`. Nothing element-level is logged, and every title or
    /// description that could reach a message is `.private`: they are the contents of
    /// someone else's screen.
    public static let accessibility = Logger(subsystem: subsystem, category: "accessibility")

    /// The permissions concern: ``AccessibilityTrustChecking`` and
    /// ``AccessibilityGateViewModel``.
    ///
    /// Its own category, separate from `accessibility` above, because it tells a
    /// different story — whether this process holds a TCC grant, not what a read of
    /// another app's tree cost — and because it is the stream #13's verification reads:
    /// `log stream --predicate 'category == "permissions"'`.
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")

    /// The configuration concern: ``ConfigStore``'s loads and what applying them did —
    /// today, whether `launch_at_login` registered or unregistered the login item.
    ///
    /// Its own category because it is the stream a "my config edit did nothing"
    /// investigation watches: `log stream --predicate 'category == "config"'`. The
    /// outcome words (`registered`, `unregistered`, `failed`) are `.public`; anything
    /// read from the user's file or from an OS error message is `.private` — with one
    /// exception, ``ConfigError/message`` on a failed reload, which is `.public` because
    /// a line number and a key name are what that investigation has to read
    /// (``StatusMenuModel/reloadConfig()``).
    public static let config = Logger(subsystem: subsystem, category: "config")

    /// The triggers concern: ``TriggerController`` registering the four global shortcuts
    /// through ``TriggerRegistering``, and every press it hears.
    ///
    /// Its own category because it is the stream a "my shortcut does nothing"
    /// investigation watches: `log stream --predicate 'category == "triggers"'`. Entry
    /// point names, key combinations, and OS status codes are `.public` — a shortcut is
    /// configuration vocabulary, not user data.
    public static let triggers = Logger(subsystem: subsystem, category: "triggers")

    /// The hints concern: ``HintSession`` turning a trigger press into hints, a typed
    /// label into a click, and why a press showed nothing.
    ///
    /// Its own category because it is the stream a "my shortcut shows no hints" or "the
    /// wrong thing was clicked" investigation watches, and the one the 300 ms budget is
    /// read from: `log stream --predicate 'category == "hints"'`. Entry points, counts,
    /// durations, labels, and reasons are `.public`; nothing element-level beyond a role
    /// is logged, and no title or description ever reaches a line.
    public static let hints = Logger(subsystem: subsystem, category: "hints")

    /// The Settings window concern: ``SettingsViewModel`` refreshing what the window
    /// shows, the pane it shows, and what its buttons did, and the status menu asking
    /// for the window.
    ///
    /// Its own category because it is the stream a "Settings… did nothing" or "the
    /// window shows the wrong state" investigation watches: `log stream --predicate
    /// 'category == "settings"'`. Pane names, the grant's state, and the file's state are
    /// `.public`; the config file's path never reaches a line.
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
