@testable import HintjumpCore
import Testing

/// The `"ctrl+shift+space"` form: what it accepts, what it refuses, and how it is
/// written back.
@Suite("KeyCombination")
struct KeyCombinationTests {
    @Test(arguments: [
        ("ctrl+shift+space", Set<KeyModifier>([.control, .shift]), "space"),
        ("ctrl+alt+shift+space", Set([.control, .option, .shift]), "space"),
        ("cmd+m", Set([.command]), "m"),
        ("CTRL+Shift+F12", Set([.control, .shift]), "f12"),
        ("ctrl+shift+7", Set([.control, .shift]), "7"),
        ("ctrl+shift+/", Set([.control, .shift]), "/"),
        ("ctrl+shift+return", Set([.control, .shift]), "return"),
        ("ctrl+shift+tab", Set([.control, .shift]), "tab"),
    ])
    func `parses a modifier list and a key`(
        text: String,
        modifiers: Set<KeyModifier>,
        key: String,
    ) throws {
        let combination = try KeyCombination.parse(text)

        #expect(combination.modifiers == modifiers)
        #expect(combination.key.rawValue == key)
    }

    @Test(arguments: [
        ("", KeyCombinationSyntaxError.empty),
        ("space", .noModifier("space")),
        ("ctrl+escape", .unknownKey("escape")),
        ("ctrl+f13", .unknownKey("f13")),
        ("ctrl+ab", .unknownKey("ab")),
        ("ctrl+あ", .unknownKey("あ")),
        ("ctrl+", .unknownKey("")),
        ("hyper+space", .unknownModifier("hyper")),
        ("ctrl+ctrl+space", .duplicateModifier(.control)),
    ])
    func `refuses what is not a combination`(text: String, expected: KeyCombinationSyntaxError) {
        #expect(throws: expected) {
            try KeyCombination.parse(text)
        }
    }

    @Test
    func `writes modifiers back in the canonical order`() throws {
        let combination = try KeyCombination.parse("shift+cmd+alt+ctrl+space")

        #expect(combination.description == "ctrl+alt+shift+cmd+space")
    }

    @Test
    func `treats the same modifiers in a different order as the same combination`() throws {
        #expect(try KeyCombination.parse("ctrl+shift+m") == KeyCombination.parse("shift+ctrl+m"))
    }

    @Test
    func `orders modifiers as they are written`() {
        #expect(KeyModifier.allCases.sorted().map(\.rawValue) == ["ctrl", "alt", "shift", "cmd"])
    }
}
