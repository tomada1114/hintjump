import Foundation
@testable import HintjumpCore
import Testing

/// The fake every Core test of ``ConfigFileAccessing`` uses: a real, working
/// implementation backed by a string, which records what it was asked
/// (`.claude/rules/testing.md` › Fakes, not mocks).
///
/// A class, so a test can read back what the store wrote through the same instance it
/// handed over. `@unchecked Sendable` is sound here because every instance is created,
/// driven, and read on the one actor its ``ConfigStore`` runs on — the port is
/// `Sendable` for adapters that really do cross actors, which this one never does.
final class FakeConfigFile: ConfigFileAccessing, @unchecked Sendable {
    /// The file's contents, or `nil` for "no such file".
    var contents: String?
    /// Every text handed to ``write(_:)``, in order.
    var writes: [String] = []
    /// Set to have the next read fail, standing in for an unreadable file.
    var readError: (any Error)?
    /// Set to have the next write fail, standing in for a read-only directory.
    var writeError: (any Error)?

    let path = "/fake/config.toml"

    init(contents: String?) {
        self.contents = contents
    }

    func read() throws -> String? {
        if let readError {
            throw readError
        }
        return contents
    }

    func write(_ text: String) throws {
        if let writeError {
            throw writeError
        }
        writes.append(text)
        contents = text
    }
}

/// An error a fake file can fail a read with.
struct FakeFileError: Error, Equatable {}

/// Some fixed instant; which one does not matter, only that it does not move.
private let fakeClockEpochSeconds: TimeInterval = 1_700_000_000

/// The fixed instant ``ConfigStore``'s clock answers in these tests, so ``lastLoad``'s
/// date is an assertion rather than a moving target.
let fakeClock = Date(timeIntervalSince1970: fakeClockEpochSeconds)

/// Loading, reloading, and the one write-back — all against the fake, so the decisions
/// stay where the coverage floor sees them.
@MainActor
@Suite("ConfigStore")
struct ConfigStoreTests {
    static func store(_ file: FakeConfigFile) -> ConfigStore {
        ConfigStore(file: file) { fakeClock }
    }

    @Test
    func `writes the default file when there is none, then reads it`() throws {
        let file = FakeConfigFile(contents: nil)
        let store = Self.store(file)

        let config = try store.load()

        #expect(file.writes == [HintjumpConfig.defaultFileContents])
        #expect(config == HintjumpConfig.default)
        #expect(store.config == HintjumpConfig.default)
    }

    @Test
    func `leaves an existing file alone`() throws {
        let file = FakeConfigFile(contents: "[startup]\nlaunch_at_login = true\n")
        let store = Self.store(file)

        #expect(try store.load().launchAtLogin)
        #expect(file.writes.isEmpty)
    }

    @Test
    func `records the successful load with its time`() throws {
        let file = FakeConfigFile(contents: "[startup]\nlaunch_at_login = true\n")
        let store = Self.store(file)

        try store.load()

        let record = try #require(store.lastLoad)
        #expect(record.date == fakeClock)
        #expect(record.result == .success(store.config))
    }

    @Test
    func `records a parse failure and keeps the last good configuration`() throws {
        let file = FakeConfigFile(contents: "[triggers]\nclick_in_window = \"ctrl+shift+space\"\n")
        let store = Self.store(file)
        try store.load()

        file.contents = "[triggers]\nhotkey_left = \"ctrl+a\"\n"
        #expect(throws: ConfigError(line: 2, reason: "unknown key `hotkey_left`")) {
            try store.reload()
        }

        let record = try #require(store.lastLoad)
        #expect(record.result == .failure(ConfigError(
            line: 2,
            reason: "unknown key `hotkey_left`",
        )))
        #expect(store.config == HintjumpConfig.default)
    }

    @Test
    func `has no load record before the first load`() {
        #expect(Self.store(FakeConfigFile(contents: nil)).lastLoad == nil)
    }

    @Test
    func `reload picks up an edit`() throws {
        let file = FakeConfigFile(contents: "[startup]\nlaunch_at_login = true\n")
        let store = Self.store(file)
        try store.load()

        file.contents = "[startup]\nlaunch_at_login = false\n"

        #expect(try store.reload().launchAtLogin == false)
    }

    @Test
    func `surfaces a read failure rather than writing the default over it`() {
        let file = FakeConfigFile(contents: "[apps]\ndisabled = []\n")
        file.readError = FakeFileError()
        let store = Self.store(file)

        #expect(throws: FakeFileError()) {
            try store.load()
        }
        #expect(file.writes.isEmpty)
        #expect(store.lastLoad == nil)
    }

    @Test
    func `surfaces a failure to write the default file`() {
        let file = FakeConfigFile(contents: nil)
        file.writeError = FakeFileError()
        let store = Self.store(file)

        #expect(throws: FakeFileError()) {
            try store.load()
        }
        #expect(store.lastLoad == nil)
    }

    @Test
    func `answers the port's path`() {
        #expect(Self.store(FakeConfigFile(contents: nil)).path == "/fake/config.toml")
    }

    @Test
    func `adds and removes a bundle identifier, touching nothing else`() throws {
        let original = "# keep me\n\n[apps]\ndisabled = []   # and me\n"
        let file = FakeConfigFile(contents: original)
        let store = Self.store(file)
        try store.load()

        try store.setDisabled("com.apple.Finder", true)

        #expect(file
            .contents == "# keep me\n\n[apps]\ndisabled = [\"com.apple.Finder\"]   # and me\n")
        #expect(store.config.disabledApps == ["com.apple.Finder"])

        try store.setDisabled("com.apple.Finder", false)

        #expect(file.contents == original)
        #expect(store.config.disabledApps.isEmpty)
    }

    @Test
    func `writes nothing when the list already says what was asked for`() throws {
        let file = FakeConfigFile(contents: "[apps]\ndisabled = [\"one\"]\n")
        let store = Self.store(file)

        try store.setDisabled("one", true)
        try store.setDisabled("two", false)

        #expect(file.writes.isEmpty)
    }

    @Test
    func `disabling against a missing file starts from the default`() throws {
        let file = FakeConfigFile(contents: nil)
        let store = Self.store(file)

        try store.setDisabled("com.apple.Finder", true)

        #expect(file.contents?.contains(#"disabled = ["com.apple.Finder"]"#) == true)
        #expect(file.contents?.hasPrefix("# Hintjump configuration.") == true)
    }

    @Test
    func `refuses to write back over a file it cannot parse`() {
        let file = FakeConfigFile(contents: "[apps]\nhotkey_left = \"ctrl+a\"\n")
        let store = Self.store(file)

        #expect(throws: ConfigError(line: 2, reason: "unknown key `hotkey_left`")) {
            try store.setDisabled("one", true)
        }
        #expect(file.writes.isEmpty)
    }
}
