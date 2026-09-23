import Foundation

/// Reads the configuration file, remembers the last attempt, and writes changed keys
/// back in place.
///
/// `@MainActor` because the Status window reads ``lastLoad`` and the status menu calls
/// ``setDisabled(_:_:)``; the file access it delegates to is a port, so a test drives
/// the whole thing against a fake with no file system in sight.
///
/// Reload is explicit — the status menu's "Reload Config" — and there is no file
/// watching: a user editing a file half-way through a save would otherwise be read
/// mid-edit and told their file is broken.
///
/// Every adoption — a successful load, reload, or ``update(_:)`` — also makes the login
/// item match `[startup] launch_at_login` (``LoginItemSync``), so editing the key and
/// reloading is how a user turns launch at login on or off. The rest of applying an
/// adopted configuration — the triggers and the disabled-apps policy — is
/// ``ConfigApplier``'s, which every caller runs after an adoption.
@MainActor
public final class ConfigStore {
    /// What the last ``load()`` or ``reload()`` produced, and when.
    ///
    /// Kept as a ``Result`` rather than an optional error so the Status window can show
    /// either `Loaded at 12:03` or the line-numbered failure from the same value,
    /// without a second "did it work" flag that could disagree with it.
    public struct LoadRecord: Equatable, Sendable {
        public let date: Date
        public let result: Result<HintjumpConfig, ConfigError>

        public init(date: Date, result: Result<HintjumpConfig, ConfigError>) {
            self.date = date
            self.result = result
        }
    }

    /// The configuration in force. A failed reload leaves the last good one in place:
    /// the app keeps working while the user fixes the file.
    public private(set) var config: HintjumpConfig = .default
    /// The last read attempt, or `nil` before the first one.
    public private(set) var lastLoad: LoadRecord?

    private let file: ConfigFileAccessing
    private let loginItem: LoginItemSync
    private let now: @Sendable () -> Date

    /// Where the file is, for the Status window and for an error message.
    public var path: String {
        file.path
    }

    /// Takes the clock as a parameter so a test can assert on ``lastLoad``'s date
    /// without waiting for one.
    ///
    /// `loginItem` is required rather than optional: a store that could be built
    /// without one is a store the composition root could forget to wire, and then
    /// `launch_at_login` would silently do nothing.
    public init(
        file: ConfigFileAccessing,
        loginItem: any LoginItemRegistering,
        now: @escaping @Sendable () -> Date,
    ) {
        self.file = file
        self.loginItem = LoginItemSync(loginItem: loginItem)
        self.now = now
    }

    /// The clock every caller outside a test wants.
    public convenience init(file: ConfigFileAccessing, loginItem: any LoginItemRegistering) {
        self.init(file: file, loginItem: loginItem) { Date() }
    }

    /// Reads the file, writing the commented default first when there is none, then
    /// makes the login item match what it says.
    ///
    /// The write happens before the parse, and the default's own text is what gets
    /// parsed, so a fresh machine and an untouched file take exactly the same path.
    ///
    /// A failure is logged before it is thrown, so a caller with nowhere to show it —
    /// the load at launch — loses nothing by discarding it. The login item is applied
    /// only after a successful parse, and its own failure is logged, never thrown: the
    /// file was read fine, so the load succeeded.
    @discardableResult
    public func load() throws -> HintjumpConfig {
        let parsed: HintjumpConfig
        do {
            parsed = try parse(readOrCreate())
        } catch {
            let failure = String(describing: error)
            AppLog.config.error("config load failed: \(failure, privacy: .private)")
            throw error
        }
        adopt(parsed)
        return parsed
    }

    /// Re-reads the file on request. Identical to ``load()`` — including writing the
    /// default if the file has since been deleted — and named separately because that
    /// is what the menu item does.
    @discardableResult
    public func reload() throws -> HintjumpConfig {
        try load()
    }

    /// Changes the configuration and writes back only the keys whose value changed,
    /// each one's value replaced in place, leaving every other byte of the file —
    /// comments included — untouched (``ConfigRewriter``). Returns what was adopted.
    ///
    /// `change` is applied to what the file says now, not to ``config``: the file is the
    /// source of truth, and an edit a user saved without reloading is kept rather than
    /// written over. A file that does not parse refuses the update with its own
    /// ``ConfigError`` — the user may be halfway through fixing it. The rewritten text
    /// is validated before it is written, so a change a hand edit could not make — two
    /// triggers on one combination, too few hint characters — is refused with the same
    /// line-numbered error, and nothing is written.
    ///
    /// An unchanged configuration writes nothing, but what the file says is adopted
    /// either way, so a file edited to say the same thing before a reload still takes
    /// effect. A missing file is updated from the default's text.
    @discardableResult
    public func update(_ change: (inout HintjumpConfig) -> Void) throws -> HintjumpConfig {
        let text = try file.read() ?? HintjumpConfig.defaultFileContents
        let current = try ConfigSchema.config(from: text)
        var changed = current
        change(&changed)
        let rewritten = try ConfigRewriter.rewrite(text, changing: current, to: changed)
        guard rewritten != text else {
            adopt(current)
            return current
        }
        let validated = try ConfigSchema.config(from: rewritten)
        try file.write(rewritten)
        adopt(validated)
        return validated
    }

    /// Adds or removes a bundle identifier in `[apps] disabled` — an ``update(_:)`` of
    /// that one list.
    ///
    /// Asking to disable an app that is already disabled, or to enable one that is not,
    /// changes nothing and so writes nothing.
    public func setDisabled(_ bundleID: String, _ disabled: Bool) throws {
        try update { config in
            if disabled {
                if !config.disabledApps.contains(bundleID) {
                    config.disabledApps.append(bundleID)
                }
            } else {
                config.disabledApps.removeAll { $0 == bundleID }
            }
        }
    }

    /// The file's text, or the default's after writing it when there is no file.
    private func readOrCreate() throws -> String {
        if let existing = try file.read() {
            return existing
        }
        let text = HintjumpConfig.defaultFileContents
        try file.write(text)
        return text
    }

    /// Parses `text`, recording a failure as the last attempt.
    private func parse(_ text: String) throws -> HintjumpConfig {
        do {
            return try ConfigSchema.config(from: text)
        } catch {
            lastLoad = LoadRecord(date: now(), result: .failure(error))
            throw error
        }
    }

    /// Puts `parsed` in force: records it as the last attempt and makes the login item
    /// match it. The login item's own failure is logged, never thrown — the file was
    /// read fine, so the adoption succeeded.
    private func adopt(_ parsed: HintjumpConfig) {
        config = parsed
        lastLoad = LoadRecord(date: now(), result: .success(parsed))
        loginItem.apply(launchAtLogin: parsed.launchAtLogin)
    }
}
