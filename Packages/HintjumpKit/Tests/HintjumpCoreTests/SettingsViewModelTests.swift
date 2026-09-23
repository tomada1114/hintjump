import Foundation
@testable import HintjumpCore
import Testing

/// The fake every Core test of ``SystemSettingsOpening`` uses: it counts the requests
/// (`.claude/rules/testing.md` › Fakes, not mocks).
@MainActor
final class FakeSystemSettingsOpener: SystemSettingsOpening {
    /// How many times ``openAccessibilitySettings()`` was called.
    private(set) var openCount = 0

    func openAccessibilitySettings() {
        openCount += 1
    }
}

/// The fake every Core test of ``PasteboardWriting`` uses: a pasteboard that keeps every
/// text it was handed, in order.
@MainActor
final class FakePasteboard: PasteboardWriting {
    /// Every text handed to ``copy(_:)``, in order.
    private(set) var copied: [String] = []

    func copy(_ text: String) {
        copied.append(text)
    }
}

/// The Settings window's state and actions — the sidebar, the attention flags, and the
/// Getting Started rows — against fakes of every port, so each stays a decision the
/// coverage floor sees. The Config File and About facts are in
/// `SettingsViewModelConfigFileTests.swift`.
@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    /// The pieces one test drives, built over the same fakes the model holds.
    struct Harness {
        let file: FakeConfigFile
        let trust: FakeAccessibilityTrustChecking
        let registrar: FakeTriggerRegistrar
        let store: ConfigStore
        let gate: AccessibilityGateViewModel
        let opener: FakeConfigFileOpener
        let systemSettings: FakeSystemSettingsOpener
        let pasteboard: FakePasteboard
        let model: SettingsViewModel
    }

    /// The version every harness reports.
    static let version = AppVersion(version: "0.1.0", build: "1")

    /// The home folder every harness reports unless a test says otherwise; the fake
    /// file's path, `/fake/config.toml`, is inside it.
    static let home = "/fake"

    /// A model over the default file, before anything was loaded or refreshed.
    static func harness() -> Harness {
        harness(contents: HintjumpConfig.defaultFileContents, home: home)
    }

    /// A model over a file holding `contents` (`nil` for no file).
    static func harness(contents: String?) -> Harness {
        harness(contents: contents, home: home)
    }

    /// A model over the default file, with `home` as the home folder.
    static func harness(home: String) -> Harness {
        harness(contents: HintjumpConfig.defaultFileContents, home: home)
    }

    /// A model over a file holding `contents` (`nil` for no file), before anything was
    /// loaded or refreshed, with `home` as the home folder and a clock that always
    /// reads "10:42".
    static func harness(contents: String?, home: String) -> Harness {
        let file = FakeConfigFile(contents: contents)
        let trust = FakeAccessibilityTrustChecking()
        let registrar = FakeTriggerRegistrar()
        let store = ConfigStoreTests.store(file)
        let controller = TriggerController(registrar: registrar)
        let policy = DisabledAppsPolicy(
            controller: controller,
            observer: FakeFrontmostAppObserver(),
        ) { store.config }
        let applier = ConfigApplier(store: store, controller: controller, policy: policy)
        let gate = AccessibilityGateViewModel(trust: trust)
        let opener = FakeConfigFileOpener()
        let systemSettings = FakeSystemSettingsOpener()
        let pasteboard = FakePasteboard()
        let system = SettingsSystem(
            ports: SettingsPorts(
                systemSettings: systemSettings,
                configFile: opener,
                pasteboard: pasteboard,
            ),
            version: version,
            homeDirectory: home,
        ) { _ in "10:42" }
        let model = SettingsViewModel(store: store, applier: applier, gate: gate, system: system)
        return Harness(
            file: file,
            trust: trust,
            registrar: registrar,
            store: store,
            gate: gate,
            opener: opener,
            systemSettings: systemSettings,
            pasteboard: pasteboard,
            model: model,
        )
    }

    // MARK: - The sidebar

    @Test
    func `shows every pane in sidebar order, Getting Started first`() {
        let model = Self.harness().model

        #expect(model.panes == SettingsPane.allCases)
        #expect(model.selection == .gettingStarted)
    }

    @Test(arguments: SettingsPane.allCases)
    func `selecting a pane shows it`(pane: SettingsPane) {
        let model = Self.harness().model

        model.select(pane)

        #expect(model.selection == pane)
    }

    /// A list reports "nothing selected" when a click lands between rows; the window
    /// keeps showing the pane it had rather than an empty detail.
    @Test
    func `deselecting keeps the pane that was showing`() {
        let model = Self.harness().model
        model.select(.about)

        model.select(nil)

        #expect(model.selection == .about)
    }

    // MARK: - Attention

    @Test(arguments: [
        (true, false),
        (false, true),
    ])
    func `getting started needs attention exactly while Accessibility is not allowed`(
        trusted: Bool,
        attention: Bool,
    ) {
        let harness = Self.harness()
        harness.trust.isTrusted = trusted

        harness.model.refresh()

        #expect(harness.model.needsAttention(.gettingStarted) == attention)
        #expect(
            harness.model.accessibilityValue(for: .gettingStarted)
                == (attention ? "Needs attention" : nil),
        )
    }

    /// Before the first check nothing says the grant is held, so the pane that asks for
    /// it is the one to look at.
    @Test
    func `getting started needs attention before the grant was ever checked`() {
        let model = Self.harness().model

        #expect(model.needsAttention(.gettingStarted))
    }

    @Test
    func `config file needs attention while the last load failed, and not after a good one`(
    ) throws {
        let harness = Self.harness(contents: "[triggers]\nclick_in_window = \"space\"\n")
        #expect(throws: ConfigError.self) { try harness.store.load() }

        #expect(harness.model.needsAttention(.configFile))
        #expect(harness.model.accessibilityValue(for: .configFile) == "Needs attention")

        harness.file.contents = HintjumpConfig.defaultFileContents
        try harness.store.reload()

        #expect(!harness.model.needsAttention(.configFile))
        #expect(harness.model.accessibilityValue(for: .configFile) == nil)
    }

    @Test
    func `config file needs no attention before the first load`() {
        #expect(!Self.harness().model.needsAttention(.configFile))
    }

    @Test
    func `about never needs attention`() throws {
        let harness = Self.harness(contents: "not toml")
        #expect(throws: ConfigError.self) { try harness.store.load() }

        #expect(!harness.model.needsAttention(.about))
    }

    // MARK: - Getting Started

    @Test(arguments: [
        (true, "Allowed", nil as String?),
        (false, "Not allowed yet", "Allow Accessibility first, then try the shortcuts here."),
    ])
    func `says whether Accessibility is allowed, and holds the shortcuts back until it is`(
        trusted: Bool,
        status: String,
        notice: String?,
    ) {
        let harness = Self.harness()
        harness.trust.isTrusted = trusted

        harness.model.refresh()

        #expect(harness.model.isAccessibilityAllowed == trusted)
        #expect(harness.model.accessibilityStatus == status)
        #expect(harness.model.tryItNotice == notice)
    }

    /// A grant given in System Settings arrives with no callback; the window learns of it
    /// when it asks again.
    @Test
    func `each refresh asks for the grant again`() {
        let harness = Self.harness()
        harness.model.refresh()
        #expect(!harness.model.isAccessibilityAllowed)

        harness.trust.isTrusted = true
        harness.model.refresh()

        #expect(harness.model.isAccessibilityAllowed)
    }

    @Test
    func `open system settings opens the Accessibility pane`() {
        let harness = Self.harness()

        harness.model.openAccessibilitySettings()

        #expect(harness.systemSettings.openCount == 1)
    }

    @Test
    func `lists the four shortcuts with the default combinations before anything loads`() {
        let lines = Self.harness().model.shortcutLines

        #expect(lines.map(\.entryPoint) == EntryPoint.allCases)
        #expect(lines.map(\.sentence) == [
            "Press ⌃⇧Space now: labels appear on this window",
            "Press ⌃⌥⇧Space: the same labels, and the one you type is right-clicked",
            "Press ⌃⇧M: labels appear on the app menus in the menu bar",
            "Press ⌃⇧S: labels appear on the status icons in the menu bar",
        ])
    }

    /// Each line draws the trigger's current value as a chip, not the default.
    @Test
    func `lists the combinations the file sets`() throws {
        let harness = Self.harness(contents: """
        [triggers]
        click_in_window = "cmd+alt+j"
        status_icons = "ctrl+f5"
        """)
        try harness.store.load()

        let lines = harness.model.shortcutLines

        #expect(lines.map(\.keys) == ["⌥⌘J", "⌃⌥⇧Space", "⌃⇧M", "⌃F5"])
        #expect(lines.map(\.lead) == ["Press", "Press", "Press", "Press"])
        #expect(lines[0].rest == " now: labels appear on this window")
        #expect(lines[1].rest == ": the same labels, and the one you type is right-clicked")
        #expect(lines[0].id == .clickInWindow)
    }
}
