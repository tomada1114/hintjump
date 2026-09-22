import Carbon.HIToolbox
import HintjumpCore
@testable import HintjumpPlatform
import Testing

/// The adapter against the real Carbon hotkey API.
///
/// What a Core test with a fake cannot ask: does `RegisterEventHotKey` really accept a
/// combination as this adapter translates it, does it refuse a duplicate with a status
/// the adapter passes on, and does the teardown survive being called twice? And does the
/// key-code table cover every name the config vocabulary accepts? Everything about
/// *when* to register stays a Core test against `FakeTriggerRegistrar`.
///
/// A Carbon hotkey needs no TCC grant, so this runs from any terminal. It registers
/// `ctrl+alt+shift+cmd+f12`, which no default macOS shortcut uses, and unregisters it
/// before returning.
@Suite("CarbonTriggerRegistrar against the real Carbon hotkey API", .requiresLocalMachine)
@MainActor
struct CarbonTriggerRegistrarTests {
    /// A combination nothing on a stock Mac holds.
    static func unusedCombination() throws -> KeyCombination {
        try KeyCombination.parse("ctrl+alt+shift+cmd+f12")
    }

    /// Every name `KeyName.parse` accepts: the named keys, and each single printable
    /// ASCII character it does not reject — walked rather than listed, so a character
    /// added to the vocabulary without a key code fails here.
    static func vocabulary() -> [KeyName] {
        let named = ["space", "return", "tab"] + (1 ... 12).map { "f\($0)" }
        let printable = (0x21 ... 0x7E).compactMap(UnicodeScalar.init).map { String(Character($0)) }
        return (named + printable).compactMap(KeyName.parse).reduce(into: []) { names, name in
            if !names.contains(name) {
                names.append(name)
            }
        }
    }

    @Test
    func `registers a combination with no failure, and unregisters twice without crashing`() throws {
        let registrar = CarbonTriggerRegistrar()
        let binding = try TriggerBinding(
            entryPoint: .clickInWindow,
            combination: Self.unusedCombination(),
        )

        let failures = registrar.register([binding]) { _ in
            // A press is not what this test is about.
        }
        registrar.unregisterAll()
        registrar.unregisterAll()

        #expect(failures.isEmpty)
    }

    @Test
    func `refuses a duplicate combination with Carbon's status, and still registers the rest`(
    ) throws {
        let registrar = CarbonTriggerRegistrar()
        let duplicate = try TriggerBinding(
            entryPoint: .appMenus,
            combination: Self.unusedCombination(),
        )
        let bindings = try [
            TriggerBinding(entryPoint: .clickInWindow, combination: Self.unusedCombination()),
            duplicate,
            TriggerBinding(
                entryPoint: .statusIcons,
                combination: KeyCombination.parse("ctrl+alt+shift+cmd+f11"),
            ),
        ]

        let failures = registrar.register(bindings) { _ in
            // A press is not what this test is about.
        }
        registrar.unregisterAll()

        let refusal = TriggerRegistrationFailure(
            binding: duplicate,
            status: Int32(eventHotKeyExistsErr),
        )
        #expect(failures == [refusal])
    }

    @Test
    func `re-registers the same combination after unregistering it`() throws {
        let registrar = CarbonTriggerRegistrar()
        let binding = try TriggerBinding(
            entryPoint: .clickInWindow,
            combination: Self.unusedCombination(),
        )

        let first = registrar.register([binding]) { _ in
            // A press is not what this test is about.
        }
        registrar.unregisterAll()
        let second = registrar.register([binding]) { _ in
            // A press is not what this test is about.
        }
        registrar.unregisterAll()

        #expect(first.isEmpty)
        #expect(second.isEmpty)
    }

    @Test
    func `the key-code table maps every name the vocabulary accepts, each to its own key`() {
        let names = Self.vocabulary()
        let codes = names.compactMap(CarbonTriggerRegistrar.keyCode(for:))

        // 26 letters, 10 digits, 11 punctuation keys, space, return, tab, f1-f12.
        #expect(names.count == 26 + 10 + 11 + 3 + 12)
        #expect(codes.count == names.count)
        #expect(Set(codes).count == codes.count)
        #expect(CarbonTriggerRegistrar.keyCodes.count == names.count)
    }

    @Test
    func `the modifier mask is Carbon's, one bit per modifier`() {
        let all = CarbonTriggerRegistrar.modifierMask(for: Set(KeyModifier.allCases))

        #expect(all == UInt32(cmdKey | controlKey | optionKey | shiftKey))
        #expect(CarbonTriggerRegistrar.modifierMask(for: []) == 0)
        #expect(CarbonTriggerRegistrar.modifierMask(for: [.shift]) == UInt32(shiftKey))
    }
}
