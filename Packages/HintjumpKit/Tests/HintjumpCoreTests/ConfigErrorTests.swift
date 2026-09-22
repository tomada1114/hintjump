@testable import HintjumpCore
import Testing

/// ``ConfigError`` is what the Status window renders, so its `message` is a contract
/// and not a debugging convenience: the issue spells the shape out as
/// ``Line 12: unknown key `hotkey_left` ``.
@Suite("ConfigError")
struct ConfigErrorTests {
    @Test
    func `renders the line number before the reason`() {
        let error = ConfigError(line: 12, reason: "unknown key `hotkey_left`")

        #expect(error.message == "Line 12: unknown key `hotkey_left`")
    }

    @Test
    func `compares by line and reason`() {
        let error = ConfigError(line: 1, reason: "a")

        #expect(error == ConfigError(line: 1, reason: "a"))
        #expect(error != ConfigError(line: 2, reason: "a"))
        #expect(error != ConfigError(line: 1, reason: "b"))
    }
}
