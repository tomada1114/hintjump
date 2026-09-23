@testable import HintjumpCore
import Testing

/// A combination drawn the way macOS menus draw one — what a key chip in the Settings
/// window shows (`docs/design/settings-window.md` › Controls).
@Suite("KeyCombination display text")
struct KeyCombinationDisplayTests {
    @Test(arguments: [
        ("ctrl+shift+space", "⌃⇧Space"),
        ("ctrl+alt+shift+space", "⌃⌥⇧Space"),
        ("ctrl+shift+m", "⌃⇧M"),
        ("ctrl+shift+s", "⌃⇧S"),
        ("cmd+shift+alt+ctrl+a", "⌃⌥⇧⌘A"),
        ("cmd+7", "⌘7"),
        ("ctrl+return", "⌃Return"),
        ("ctrl+tab", "⌃Tab"),
        ("ctrl+f1", "⌃F1"),
        ("ctrl+f12", "⌃F12"),
        ("ctrl+/", "⌃/"),
        ("ctrl+`", "⌃`"),
    ])
    func `draws the modifiers in menu order, then the key`(text: String, expected: String) throws {
        let combination = try KeyCombination.parse(text)

        #expect(combination.displayText == expected)
    }

    @Test
    func `the default click-in-window trigger reads ⌃⇧Space`() {
        #expect(HintjumpConfig.default.clickInWindow.displayText == "⌃⇧Space")
    }

    @Test(arguments: [
        (KeyModifier.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘"),
    ])
    func `every modifier has its menu symbol`(modifier: KeyModifier, symbol: String) {
        #expect(KeyCombination.symbol(for: modifier) == symbol)
    }
}
