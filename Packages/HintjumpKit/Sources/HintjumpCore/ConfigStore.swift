import Foundation

/// Reads the configuration file, remembers the last attempt, and performs the one
/// write-back the app does.
///
/// `@MainActor` because the Status window reads ``lastLoad`` and the status menu calls
/// ``setDisabled(_:_:)``; the file access it delegates to is a port, so a test drives
/// the whole thing against a fake with no file system in sight.
///
/// Reload is explicit — the status menu's "Reload Config" — and there is no file
/// watching: a user editing a file half-way through a save would otherwise be read
/// mid-edit and told their file is broken.
///
/// Every successful load also makes the login item match `[startup] launch_at_login`
/// (``LoginItemSync``), so editing the key and reloading is how a user turns launch at
/// login on or off.
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
            parsed = try adopt(readOrCreate())
        } catch {
            let failure = String(describing: error)
            AppLog.config.error("config load failed: \(failure, privacy: .private)")
            throw error
        }
        loginItem.apply(launchAtLogin: parsed.launchAtLogin)
        return parsed
    }

    /// Re-reads the file on request. Identical to ``load()`` — including writing the
    /// default if the file has since been deleted — and named separately because that
    /// is what the menu item does.
    @discardableResult
    public func reload() throws -> HintjumpConfig {
        try load()
    }

    /// Adds or removes a bundle identifier in `[apps] disabled`, rewriting only that
    /// value and leaving every other byte of the file — comments included — untouched.
    ///
    /// A no-op write is skipped: asking to disable an app that is already disabled
    /// should not rewrite the user's file at all. The list the file holds is adopted
    /// either way, so a file edited to say the same thing before a reload still takes
    /// effect when the menu asks for it.
    public func setDisabled(_ bundleID: String, _ disabled: Bool) throws {
        let text = try file.read() ?? HintjumpConfig.defaultFileContents
        var bundleIDs = try ConfigSchema.config(from: text).disabledApps
        if disabled {
            guard !bundleIDs.contains(bundleID) else {
                config.disabledApps = bundleIDs
                return
            }
            bundleIDs.append(bundleID)
        } else {
            guard bundleIDs.contains(bundleID) else {
                config.disabledApps = bundleIDs
                return
            }
            bundleIDs.removeAll { $0 == bundleID }
        }
        try file.write(DisabledAppsRewriter.rewrite(text, disabled: bundleIDs))
        config.disabledApps = bundleIDs
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

    /// Parses `text`, records the attempt, and keeps the result when it is a success.
    private func adopt(_ text: String) throws -> HintjumpConfig {
        do {
            let parsed = try ConfigSchema.config(from: text)
            config = parsed
            lastLoad = LoadRecord(date: now(), result: .success(parsed))
            return parsed
        } catch {
            lastLoad = LoadRecord(date: now(), result: .failure(error))
            throw error
        }
    }
}
