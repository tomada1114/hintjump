import Foundation
import HintjumpCore
import HintjumpPlatform
import Testing

/// `UserConfigFile` against a real file system, under a temporary `HOME`.
///
/// Local-machine rather than CI, like every suite here — but for a milder reason than
/// the others: it needs no TCC grant, only a writable home directory, and it writes
/// into a temporary one so it can never touch the developer's own
/// `~/.config/hintjump/config.toml`. What it checks is the half a Core test with a fake
/// cannot: that the path resolves where the decision log says, that the directory is
/// created, and that the bytes survive a round trip.
@Suite("UserConfigFile against the real file system", .requiresLocalMachine)
struct UserConfigFileTests {
    /// A temporary directory that stands in for `HOME` for the duration of one test.
    static func withTemporaryHome<Value>(_ body: (URL) throws -> Value) throws -> Value {
        let home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("hintjump-config-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        return try body(home)
    }

    @Test
    func `resolves the documented path under HOME`() {
        let url = UserConfigFile.defaultURL(environment: ["HOME": "/Users/example"])

        #expect(url.path == "/Users/example/.config/hintjump/config.toml")
    }

    @Test
    func `falls back to the process home when HOME is unset`() {
        let url = UserConfigFile.defaultURL(environment: [:])

        #expect(url.path.hasSuffix("/.config/hintjump/config.toml"))
    }

    @Test
    func `answers nil for a file that is not there`() throws {
        try Self.withTemporaryHome { home in
            let file = UserConfigFile(url: UserConfigFile.defaultURL(
                environment: ["HOME": home.path],
            ))

            let contents = try file.read()
            #expect(contents == nil)
        }
    }

    @Test
    func `creates the directory and round-trips the default file`() throws {
        try Self.withTemporaryHome { home in
            let url = UserConfigFile.defaultURL(environment: ["HOME": home.path])
            let file = UserConfigFile(url: url)

            try file.write(HintjumpConfig.defaultFileContents)

            #expect(file.path == url.path)
            #expect(FileManager.default.fileExists(atPath: url.path))
            let contents = try file.read()
            #expect(contents == HintjumpConfig.defaultFileContents)
        }
    }

    @Test
    func `replaces the file on a second write`() throws {
        try Self.withTemporaryHome { home in
            let file = UserConfigFile(url: UserConfigFile.defaultURL(
                environment: ["HOME": home.path],
            ))
            try file.write("[apps]\ndisabled = []\n")

            try file.write("[apps]\ndisabled = [\"one\"]\n")

            let contents = try file.read()
            #expect(contents == "[apps]\ndisabled = [\"one\"]\n")
        }
    }

    @MainActor
    @Test
    func `drives a whole ConfigStore against the real file`() throws {
        try Self.withTemporaryHome { home in
            let file = UserConfigFile(url: UserConfigFile.defaultURL(
                environment: ["HOME": home.path],
            ))
            let store = ConfigStore(file: file)

            let loaded = try store.load()
            #expect(loaded == HintjumpConfig.default)
            let written = try file.read()
            #expect(written == HintjumpConfig.defaultFileContents)

            try store.setDisabled("com.apple.Finder", true)

            let rewritten = try file.read()
            #expect(
                rewritten == HintjumpConfig.defaultFileContents.replacingOccurrences(
                    of: "disabled = []",
                    with: #"disabled = ["com.apple.Finder"]"#,
                ),
            )
            let reloaded = try store.reload()
            #expect(reloaded.disabledApps == ["com.apple.Finder"])
        }
    }
}
