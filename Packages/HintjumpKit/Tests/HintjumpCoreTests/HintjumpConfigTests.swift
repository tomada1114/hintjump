@testable import HintjumpCore
import Testing

/// The default file and the values it stands for.
///
/// The round trip is the assertion that matters: ``HintjumpConfig/default`` is parsed
/// from ``HintjumpConfig/defaultFileContents``, so this suite is what keeps the file
/// the app writes on a fresh machine from drifting away from the values it runs with —
/// and, by checking the values explicitly, keeps a change to either from passing
/// unnoticed.
@Suite("HintjumpConfig defaults")
struct HintjumpConfigTests {
    @Test
    func `the default file parses to the default configuration`() throws {
        let parsed = try ConfigSchema.config(from: HintjumpConfig.defaultFileContents)

        #expect(parsed == HintjumpConfig.default)
    }

    @Test
    func `the defaults are the ones the decision log settles on`() {
        let config = HintjumpConfig.default

        #expect(config.clickInWindow.description == "ctrl+shift+space")
        #expect(config.rightClickInWindow.description == "ctrl+alt+shift+space")
        #expect(config.appMenus.description == "ctrl+shift+m")
        #expect(config.statusIcons.description == "ctrl+shift+s")
        #expect(String(config.hintCharacters) == "asdfghjklqwertyuiopzxcvbnm")
        #expect(config.disabledApps.isEmpty)
        #expect(config.launchAtLogin == false)
    }

    @Test
    func `the default file is the commented one the app writes`() {
        let text = HintjumpConfig.defaultFileContents

        #expect(text.hasPrefix("# Hintjump configuration."))
        #expect(text.contains("\n[triggers]\n"))
        #expect(text.contains("\n[hints]\n"))
        #expect(text.contains("\n[apps]\n"))
        #expect(text.contains("\n[startup]\n"))
        #expect(text.contains("disabled = []"))
        #expect(text.hasSuffix("\n"))
    }

    @Test
    func `the built-in fallback matches the parsed default`() {
        #expect(HintjumpConfig.builtIn == HintjumpConfig.default)
    }

    @Test
    func `lists the four triggers in file order`() {
        #expect(
            HintjumpConfig.default.triggers.map(\.key)
                == ["click_in_window", "right_click_in_window", "app_menus", "status_icons"],
        )
    }
}
