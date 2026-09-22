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
    private let now: @Sendable () -> Date

    /// Where the file is, for the Status window and for an error message.
    public var path: String {
        file.path
    }

    /// Takes the clock as a parameter so a test can assert on ``lastLoad``'s date
    /// without waiting for one.
    public init(file: ConfigFileAccessing, now: @escaping @Sendable () -> Date) {
        self.file = file
        self.now = now
    }

    /// The clock every caller outside a test wants.
    public convenience init(file: ConfigFileAccessing) {
        self.init(file: file) { Date() }
    }

    /// Reads the file, writing the commented default first when there is none.
    ///
    /// The write happens before the parse, and the default's own text is what gets
    /// parsed, so a fresh machine and an untouched file take exactly the same path.
    @discardableResult
    public func load() throws -> HintjumpConfig {
        let text: String
        if let existing = try file.read() {
            text = existing
        } else {
            text = HintjumpConfig.defaultFileContents
            try file.write(text)
        }
        return try adopt(text)
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
    /// should not rewrite the user's file at all.
    public func setDisabled(_ bundleID: String, _ disabled: Bool) throws {
        let text = try file.read() ?? HintjumpConfig.defaultFileContents
        var bundleIDs = try ConfigSchema.config(from: text).disabledApps
        if disabled {
            guard !bundleIDs.contains(bundleID) else {
                return
            }
            bundleIDs.append(bundleID)
        } else {
            guard bundleIDs.contains(bundleID) else {
                return
            }
            bundleIDs.removeAll { $0 == bundleID }
        }
        try file.write(DisabledAppsRewriter.rewrite(text, disabled: bundleIDs))
        config.disabledApps = bundleIDs
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
