@testable import HintjumpCore
import Testing

/// The fake every Core test of ``TriggerRegistering`` uses: a real, working registrar
/// that holds the bindings it was handed in a plain array, lets a test press one, and
/// answers with the failures a test planted (`.claude/rules/testing.md` › Fakes, not
/// mocks).
///
/// `@MainActor`, like the port, which is what makes it `Sendable` without an
/// `@unchecked` of its own.
@MainActor
final class FakeTriggerRegistrar: TriggerRegistering {
    /// The bindings registered right now, in the order they were registered.
    private(set) var registered: [TriggerBinding] = []
    /// How many times ``unregisterAll()`` was called.
    private(set) var unregisterAllCount = 0
    /// Every call, in order, as `register` or `unregisterAll` — for the assertions where
    /// the order of asking is the behavior.
    private(set) var calls: [String] = []
    /// Entry points whose registration fails with ``failureStatus``, standing in for a
    /// combination another app already holds.
    var failing: Set<EntryPoint> = []
    /// The status a planted failure carries; the value is arbitrary but fixed.
    let failureStatus: Int32 = -9_878

    private var onPress: (@MainActor (EntryPoint) -> Void)?

    func register(
        _ bindings: [TriggerBinding],
        onPress: @escaping @MainActor (EntryPoint) -> Void,
    ) -> [TriggerRegistrationFailure] {
        calls.append("register")
        self.onPress = onPress
        var failures: [TriggerRegistrationFailure] = []
        for binding in bindings {
            if failing.contains(binding.entryPoint) {
                failures.append(TriggerRegistrationFailure(binding: binding, status: failureStatus))
            } else {
                registered.append(binding)
            }
        }
        return failures
    }

    func unregisterAll() {
        calls.append("unregisterAll")
        unregisterAllCount += 1
        registered = []
        onPress = nil
    }

    /// Presses `entryPoint`'s combination, if it is registered — as the OS would.
    func press(_ entryPoint: EntryPoint) {
        guard registered.contains(where: { $0.entryPoint == entryPoint }) else {
            return
        }
        onPress?(entryPoint)
    }

    /// The combination registered for `entryPoint`, or `nil` when there is none.
    func combination(for entryPoint: EntryPoint) -> KeyCombination? {
        registered.first { $0.entryPoint == entryPoint }?.combination
    }
}

/// A configuration whose `app_menus` is `ctrl+shift+j` instead of the default's `m`.
func configWithAppMenusOnJ() throws -> HintjumpConfig {
    var config = HintjumpConfig.default
    config.appMenus = try KeyCombination.parse("ctrl+shift+j")
    return config
}

/// Registering the four triggers and forwarding a press — the decision, against the fake.
@MainActor
@Suite("TriggerController")
struct TriggerControllerTests {
    /// The four bindings of the default configuration, in `EntryPoint.allCases` order.
    static let defaultBindings: [TriggerBinding] = EntryPoint.allCases.map { entryPoint in
        TriggerBinding(
            entryPoint: entryPoint,
            combination: HintjumpConfig.default.combination(for: entryPoint),
        )
    }

    @Test
    func `registers nothing until the first apply`() {
        let registrar = FakeTriggerRegistrar()

        let controller = TriggerController(registrar: registrar)

        #expect(registrar.calls.isEmpty)
        #expect(controller.failures.isEmpty)
    }

    @Test
    func `apply registers exactly the four bindings of the config, in entry-point order`() {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)

        controller.apply(.default)

        #expect(registrar.registered == Self.defaultBindings)
        #expect(controller.failures.isEmpty)
    }

    @Test
    func `apply unregisters before it registers, every time`() throws {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)

        controller.apply(.default)
        try controller.apply(configWithAppMenusOnJ())

        #expect(registrar.calls == ["unregisterAll", "register", "unregisterAll", "register"])
        #expect(registrar.registered.count == EntryPoint.allCases.count)
        #expect(try registrar.combination(for: .appMenus) == KeyCombination.parse("ctrl+shift+j"))
    }

    @Test
    func `keeps a failure and still registers the other three`() {
        let registrar = FakeTriggerRegistrar()
        registrar.failing = [.appMenus]
        let controller = TriggerController(registrar: registrar)

        controller.apply(.default)

        let failedBinding = TriggerBinding(
            entryPoint: .appMenus,
            combination: HintjumpConfig.default.appMenus,
        )
        #expect(controller.failures == [
            TriggerRegistrationFailure(binding: failedBinding, status: registrar.failureStatus),
        ])
        #expect(registrar.registered.map(\.entryPoint) == [
            .clickInWindow,
            .rightClickInWindow,
            .statusIcons,
        ])
    }

    @Test
    func `a later successful apply clears the earlier failures`() {
        let registrar = FakeTriggerRegistrar()
        registrar.failing = [.statusIcons, .clickInWindow]
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)
        #expect(controller.failures.count == 2)

        registrar.failing = []
        controller.apply(.default)

        #expect(controller.failures.isEmpty)
        #expect(registrar.registered == Self.defaultBindings)
    }

    @Test(arguments: EntryPoint.allCases)
    func `a press reaches onTrigger with its entry point`(_ entryPoint: EntryPoint) {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        var pressed: [EntryPoint] = []
        controller.onTrigger = { pressed.append($0) }
        controller.apply(.default)

        registrar.press(entryPoint)

        #expect(pressed == [entryPoint])
    }

    @Test
    func `a press with no onTrigger set is only logged`() {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)

        registrar.press(.clickInWindow)

        #expect(controller.onTrigger == nil)
        #expect(registrar.registered == Self.defaultBindings)
    }

    @Test
    func `a press after the controller is gone reaches nothing`() {
        let registrar = FakeTriggerRegistrar()
        var pressed: [EntryPoint] = []
        do {
            let controller = TriggerController(registrar: registrar)
            controller.onTrigger = { pressed.append($0) }
            controller.apply(.default)
        }

        registrar.press(.clickInWindow)

        #expect(pressed.isEmpty)
    }

    // MARK: - Suspension

    @Test
    func `starts not suspended`() {
        let controller = TriggerController(registrar: FakeTriggerRegistrar())

        #expect(!controller.isSuspended)
    }

    @Test
    func `suspending unregisters every trigger, and resuming registers the four again`() {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)

        controller.setSuspended(true)

        #expect(controller.isSuspended)
        #expect(registrar.registered.isEmpty)
        #expect(registrar.calls == ["unregisterAll", "register", "unregisterAll"])

        controller.setSuspended(false)

        #expect(!controller.isSuspended)
        #expect(registrar.registered == Self.defaultBindings)
        #expect(registrar.calls.suffix(2) == ["unregisterAll", "register"])
    }

    @Test(arguments: [true, false])
    func `setting the state it already has asks the registrar nothing`(_ suspended: Bool) {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)
        controller.setSuspended(suspended)
        let calls = registrar.calls

        controller.setSuspended(suspended)

        #expect(registrar.calls == calls)
        #expect(controller.isSuspended == suspended)
    }

    @Test
    func `apply while suspended registers nothing, and resuming registers what it applied`() throws {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)
        controller.setSuspended(true)
        let calls = registrar.calls

        try controller.apply(configWithAppMenusOnJ())

        #expect(registrar.calls == calls)
        #expect(registrar.registered.isEmpty)

        controller.setSuspended(false)

        #expect(try registrar.combination(for: .appMenus) == KeyCombination.parse("ctrl+shift+j"))
        #expect(registrar.registered.count == EntryPoint.allCases.count)
    }

    @Test
    func `resuming before any apply registers nothing`() {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        controller.setSuspended(true)

        controller.setSuspended(false)

        #expect(!controller.isSuspended)
        #expect(registrar.calls == ["unregisterAll"])
        #expect(registrar.registered.isEmpty)
    }

    @Test
    func `suspending clears the failures, and resuming reports them again`() {
        let registrar = FakeTriggerRegistrar()
        registrar.failing = [.statusIcons]
        let controller = TriggerController(registrar: registrar)
        controller.apply(.default)

        controller.setSuspended(true)

        #expect(controller.failures.isEmpty)

        controller.setSuspended(false)

        #expect(controller.failures.map(\.binding.entryPoint) == [.statusIcons])
    }

    @Test
    func `a press while suspended reaches nothing`() {
        let registrar = FakeTriggerRegistrar()
        let controller = TriggerController(registrar: registrar)
        var pressed: [EntryPoint] = []
        controller.onTrigger = { pressed.append($0) }
        controller.apply(.default)
        controller.setSuspended(true)

        registrar.press(.clickInWindow)

        #expect(pressed.isEmpty)
    }
}
