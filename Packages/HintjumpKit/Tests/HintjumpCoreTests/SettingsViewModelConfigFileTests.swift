import Foundation
@testable import HintjumpCore
import Testing

/// The Config File and About panes' facts and buttons, against the same harness as
/// `SettingsViewModelTests`.
@MainActor
@Suite("SettingsViewModel: Config File and About")
struct SettingsViewModelConfigFileTests {
    // MARK: - The path

    @Test(arguments: [
        ("/fake", "~/config.toml"),
        ("/fake/", "~/config.toml"),
        ("/fak", "/fake/config.toml"),
        ("/elsewhere", "/fake/config.toml"),
        ("", "/fake/config.toml"),
    ])
    func `shows the path with the home folder as ~`(home: String, shown: String) {
        let model = SettingsViewModelTests.harness(home: home).model

        #expect(model.configPath == shown)
    }

    @Test
    func `the home folder itself is ~`() {
        #expect(SettingsViewModel
            .abbreviatingHome(in: "/Users/someone", home: "/Users/someone") == "~")
    }

    @Test
    func `open, reveal in Finder, and copy path act on the full path`() {
        let harness = SettingsViewModelTests.harness()

        harness.model.openConfigFile()
        harness.model.revealConfigFile()
        harness.model.copyConfigPath()

        #expect(harness.opener.openedPaths == ["/fake/config.toml"])
        #expect(harness.opener.revealedPaths == ["/fake/config.toml"])
        #expect(harness.pasteboard.copied == ["/fake/config.toml"])
    }

    // MARK: - The last load

    @Test
    func `says nothing about a load before the first one`() {
        let model = SettingsViewModelTests.harness().model

        #expect(model.lastLoadLine == nil)
        #expect(model.lastLoadError == nil)
        #expect(model.lastLoadDate == nil)
        #expect(model.lastLoadNote == nil)
    }

    @Test
    func `a good load reads "Loaded at" and its time`() throws {
        let harness = SettingsViewModelTests.harness()
        try harness.store.load()

        #expect(harness.model.lastLoadLine == "Loaded at 10:42")
        #expect(harness.model.lastLoadDate == fakeClock)
        #expect(harness.model.lastLoadError == nil)
        #expect(harness.model.lastLoadNote == nil)
    }

    @Test
    func `a failed load reads the error's line and reason, and that the last settings stay`() {
        let harness = SettingsViewModelTests.harness(contents: "[hints]\nhotkey_left = \"abc\"\n")
        #expect(throws: ConfigError.self) { try harness.store.load() }

        let error = harness.model.lastLoadError
        #expect(error?.line == 2)
        #expect(harness.model.lastLoadLine == error?.message)
        #expect(harness.model.lastLoadLine?.hasPrefix("Line 2: ") == true)
        #expect(harness.model.lastLoadDate == fakeClock)
        #expect(harness.model.lastLoadNote == "Hintjump keeps using the last settings that loaded.")
    }

    // MARK: - The file itself

    @Test
    func `knows nothing about the file until the first refresh`() {
        let model = SettingsViewModelTests.harness().model

        #expect(model.fileState == nil)
        #expect(!model.canCreateDefaultFile)
        #expect(model.fileNotice == nil)
    }

    @Test
    func `a file that is there offers no Create Default File`() {
        let harness = SettingsViewModelTests.harness()

        harness.model.refresh()

        #expect(harness.model.fileState == .present)
        #expect(!harness.model.canCreateDefaultFile)
        #expect(harness.model.fileNotice == nil)
    }

    @Test
    func `a missing file offers Create Default File`() {
        let harness = SettingsViewModelTests.harness(contents: nil)

        harness.model.refresh()

        #expect(harness.model.fileState == .missing)
        #expect(harness.model.canCreateDefaultFile)
        #expect(harness.model.fileNotice == nil)
    }

    @Test
    func `an unreadable file says so and offers nothing to create`() {
        let harness = SettingsViewModelTests.harness()
        harness.file.readError = FakeFileError()

        harness.model.refresh()

        #expect(harness.model.fileState == .unreadable)
        #expect(!harness.model.canCreateDefaultFile)
        #expect(harness.model.fileNotice == "Hintjump couldn't read this file.")
    }

    /// The file is the source of truth, so the default it now holds is what is in force:
    /// it is loaded, and the triggers it names are registered.
    @Test
    func `create default file writes the default, loads it, and applies it`() {
        let harness = SettingsViewModelTests.harness(contents: nil)
        harness.model.refresh()

        harness.model.createDefaultFile()

        #expect(harness.file.writes == [HintjumpConfig.defaultFileContents])
        #expect(harness.store.config == .default)
        #expect(harness.model.lastLoadLine == "Loaded at 10:42")
        #expect(harness.registrar.registered.map(\.entryPoint) == EntryPoint.allCases)
        #expect(harness.model.fileState == .present)
        #expect(!harness.model.canCreateDefaultFile)
    }

    /// A write that fails leaves the triggers alone — nothing new was adopted — and the
    /// file still missing, so the button stays.
    @Test
    func `create default file that cannot write applies nothing`() {
        let harness = SettingsViewModelTests.harness(contents: nil)
        harness.file.writeError = FakeFileError()

        harness.model.createDefaultFile()

        #expect(harness.registrar.registered.isEmpty)
        #expect(harness.model.fileState == .missing)
        #expect(harness.model.canCreateDefaultFile)
    }

    // MARK: - About

    @Test
    func `about shows the version, the build, and the repository`() {
        let model = SettingsViewModelTests.harness().model

        #expect(model.versionLine == "Version 0.1.0 (1)")
        #expect(model.repositoryTitle == "github.com/tomada1114/hintjump")
        #expect(model.repositoryURL == URL(string: "https://github.com/tomada1114/hintjump"))
    }

    @Test(arguments: [
        (
            ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "45"],
            AppVersion(version: "1.2.3", build: "45"),
        ),
        ([:], AppVersion(version: "unknown", build: "unknown")),
        (["CFBundleShortVersionString": 7], AppVersion(version: "unknown", build: "unknown")),
    ] as [([String: any Sendable], AppVersion)])
    func `reads the version from the bundle's info dictionary`(
        info: [String: any Sendable],
        expected: AppVersion,
    ) {
        #expect(AppVersion(infoDictionary: info) == expected)
    }
}
