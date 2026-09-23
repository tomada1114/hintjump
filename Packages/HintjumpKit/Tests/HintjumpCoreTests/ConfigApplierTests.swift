@testable import HintjumpCore
import Testing

/// The one apply path: after any adoption, the triggers follow the store's
/// configuration and the disabled-apps policy is re-evaluated against it.
@MainActor
@Suite("ConfigApplier")
struct ConfigApplierTests {
    @Test
    func `apply re-registers the triggers from the adopted configuration`() throws {
        let harness = try StatusMenuModelTests.started()
        harness.file.contents = HintjumpConfig.defaultFileContents.replacing(
            "app_menus = \"ctrl+shift+m\"",
            with: "app_menus = \"ctrl+shift+j\"",
        )
        try harness.store.reload()
        #expect(harness.registrar.combination(for: .appMenus)?.description == "ctrl+shift+m")

        harness.applier.apply()

        #expect(try harness.registrar.combination(for: .appMenus) == KeyCombination
            .parse("ctrl+shift+j"))
        #expect(harness.registrar.registered.count == EntryPoint.allCases.count)
        #expect(harness.registrar.unregisterAllCount == 2)
    }

    @Test
    func `apply re-evaluates the policy, suspending and resuming for the frontmost app`() throws {
        let harness = try StatusMenuModelTests.started(
            contents: HintjumpConfig.defaultFileContents,
            frontmost: DisabledAppsPolicyTests.textEdit,
        )
        try harness.store.update { $0.disabledApps = ["com.apple.TextEdit"] }
        #expect(!harness.controller.isSuspended)

        harness.applier.apply()

        #expect(harness.controller.isSuspended)
        #expect(harness.registrar.registered.isEmpty)
        #expect(harness.policy.isLastExternalAppDisabled)

        try harness.store.update { $0.disabledApps = [] }
        harness.applier.apply()

        #expect(!harness.controller.isSuspended)
        #expect(harness.registrar.registered == TriggerControllerTests.defaultBindings)
        #expect(!harness.policy.isLastExternalAppDisabled)
    }

    @Test
    func `a trigger changed while suspended is what resuming registers`() throws {
        let harness = try StatusMenuModelTests.started(
            contents: StatusMenuModelTests.Disable.textEditDisabled,
            frontmost: DisabledAppsPolicyTests.textEdit,
        )
        #expect(harness.controller.isSuspended)
        try harness.store.update { config in
            config.appMenus = KeyCombination(modifiers: [.control, .shift], key: .space)
            config.clickInWindow = KeyCombination(modifiers: [.control, .shift], key: .letterM)
        }
        harness.applier.apply()
        #expect(harness.registrar.registered.isEmpty)

        try harness.store.update { $0.disabledApps = [] }
        harness.applier.apply()

        #expect(harness.registrar.combination(for: .appMenus)?.description == "ctrl+shift+space")
        #expect(harness.registrar.combination(for: .clickInWindow)?.description == "ctrl+shift+m")
    }
}
