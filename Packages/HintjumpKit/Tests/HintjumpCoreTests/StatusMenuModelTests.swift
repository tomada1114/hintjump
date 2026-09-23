@testable import HintjumpCore
import Testing

/// The fake every Core test of ``ConfigFileOpening`` uses: it records each path it was
/// asked to open (`.claude/rules/testing.md` › Fakes, not mocks).
@MainActor
final class FakeConfigFileOpener: ConfigFileOpening {
    /// Every path handed to ``open(path:)``, in order.
    private(set) var openedPaths: [String] = []

    func open(path: String) {
        openedPaths.append(path)
    }
}

/// The status menu's two config items — against fakes of the file, the registrar, and
/// the opener, so both stay decisions the coverage floor sees.
@MainActor
@Suite("StatusMenuModel")
struct StatusMenuModelTests {
    /// The pieces one test drives, built over the same fakes the model holds.
    struct Harness {
        let file: FakeConfigFile
        let registrar: FakeTriggerRegistrar
        let store: ConfigStore
        let controller: TriggerController
        let opener: FakeConfigFileOpener
        let observer: FakeFrontmostAppObserver
        let policy: DisabledAppsPolicy
        let applier: ConfigApplier
        let model: StatusMenuModel
    }

    /// A model over the default file with no app frontmost, started the way `App/`
    /// starts it.
    static func started() throws -> Harness {
        try started(contents: HintjumpConfig.defaultFileContents, frontmost: nil)
    }

    /// A model over `contents`, loaded, applied, and started with `frontmost` in front,
    /// the way `App/` starts it.
    static func started(contents: String, frontmost: FrontmostApp?) throws -> Harness {
        let file = FakeConfigFile(contents: contents)
        let registrar = FakeTriggerRegistrar()
        let store = ConfigStoreTests.store(file)
        let controller = TriggerController(registrar: registrar)
        let opener = FakeConfigFileOpener()
        let observer = FakeFrontmostAppObserver()
        let policy = DisabledAppsPolicy(controller: controller, observer: observer) { store.config }
        let applier = ConfigApplier(store: store, controller: controller, policy: policy)
        let model = StatusMenuModel(
            store: store,
            applier: applier,
            opener: opener,
            policy: policy,
        )
        try store.load()
        applier.apply()
        policy.start(from: frontmost)
        return Harness(
            file: file,
            registrar: registrar,
            store: store,
            controller: controller,
            opener: opener,
            observer: observer,
            policy: policy,
            applier: applier,
            model: model,
        )
    }

    @Test
    func `open config file hands the store's path to the opener`() throws {
        let harness = try Self.started()

        harness.model.openConfigFile()

        #expect(harness.opener.openedPaths == [harness.file.path])
    }

    @Test
    func `reload with a changed combination re-registers it`() throws {
        let harness = try Self.started()
        harness.file.contents = HintjumpConfig.defaultFileContents.replacing(
            "app_menus = \"ctrl+shift+m\"",
            with: "app_menus = \"ctrl+shift+j\"",
        )

        harness.model.reloadConfig()

        #expect(try harness.registrar.combination(for: .appMenus) == KeyCombination
            .parse("ctrl+shift+j"))
        #expect(harness.registrar.registered.count == EntryPoint.allCases.count)
        #expect(harness.registrar.unregisterAllCount == 2)
        #expect(try harness.store.config == configWithAppMenusOnJ())
    }

    @Test
    func `a failed reload leaves the registered triggers untouched`() throws {
        let harness = try Self.started()
        let before = harness.registrar.registered
        harness.file.contents = HintjumpConfig.defaultFileContents + "\nhotkey_left = \"x\"\n"

        harness.model.reloadConfig()

        #expect(harness.registrar.registered == before)
        #expect(harness.registrar.calls == ["unregisterAll", "register"])
        #expect(harness.store.config == .default)
        let failure = try #require(harness.store.lastLoad?.result.failureValue)
        #expect(failure.reason == "unknown key `hotkey_left`")
    }

    @Test
    func `an unreadable file on reload leaves the registered triggers untouched`() throws {
        let harness = try Self.started()
        let before = harness.registrar.registered
        harness.file.readError = FakeFileError()

        harness.model.reloadConfig()

        #expect(harness.registrar.registered == before)
        #expect(harness.registrar.calls == ["unregisterAll", "register"])
    }
}

extension Result {
    /// The error, or `nil` for a success — so a test can `#require` the payload.
    var failureValue: Failure? {
        guard case let .failure(error) = self else {
            return nil
        }
        return error
    }
}
