import Foundation
import HintjumpCore

/// The `~/.config/hintjump/config.toml`-backed adapter for
/// ``HintjumpCore/ConfigFileAccessing``.
///
/// A dotfile path rather than Application Support: the file is meant to be opened in an
/// editor, kept in a dotfiles repository, and shared, and Application Support is for
/// data the app manages on the user's behalf (`docs/decisions.md` › "Config file: a
/// hand-written TOML subset, one path, one write-back").
///
/// Translation only, as every adapter here is: it resolves one path, creates the
/// directory, and moves bytes. The grammar, the schema, and the write-back all live in
/// Core, where the coverage floor sees them; what cannot be checked there — that the
/// path really resolves and that an atomic write really lands — is
/// `UserConfigFileTests`, run by hand with `just test-local`.
public struct UserConfigFile: ConfigFileAccessing {
    /// The file's location, resolved once at construction.
    public let path: String

    private let url: URL

    /// The file at `url`.
    public init(url: URL) {
        self.url = url
        path = url.path
    }

    /// The file under the current process's `HOME`.
    public init() {
        self.init(url: Self.defaultURL(environment: ProcessInfo.processInfo.environment))
    }

    /// The default location, `~/.config/hintjump/config.toml`.
    ///
    /// `HOME` rather than `FileManager.homeDirectoryForCurrentUser`: in a sandboxed
    /// process the latter answers the container, and this file is deliberately outside
    /// it. It is also what lets the local-machine test run under a temporary `HOME`
    /// instead of writing into the developer's real one.
    public static func defaultURL(environment: [String: String]) -> URL {
        let home = environment["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("hintjump", isDirectory: true)
            .appendingPathComponent("config.toml", isDirectory: false)
    }

    /// The file's contents, or `nil` when it does not exist.
    ///
    /// Only a missing file answers `nil`; an unreadable one throws, so a permissions
    /// problem is never mistaken for a fresh machine and answered by writing the
    /// default over it.
    public func read() throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Replaces the file, creating `~/.config/hintjump` if it is not there.
    ///
    /// Atomic: the write lands as a rename, so a crash or a full disk leaves the
    /// previous file intact rather than a half-written one the app would then refuse
    /// to parse.
    public func write(_ text: String) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
