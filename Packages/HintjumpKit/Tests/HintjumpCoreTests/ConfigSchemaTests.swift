@testable import HintjumpCore
import Testing

/// Everything a well-formed file can still say wrong, and the line it is told on.
@Suite("Config schema")
struct ConfigSchemaTests {
    /// A complete, valid file with every value changed away from the default, so a
    /// value the schema silently ignored would show up as a default here.
    static let filledFile = """
    [triggers]
    click_in_window = "cmd+1"
    right_click_in_window = "cmd+2"
    app_menus = "cmd+3"
    status_icons = "cmd+4"

    [hints]
    characters = "qwertyui"

    [apps]
    disabled = ["com.apple.Finder"]

    [startup]
    launch_at_login = true
    """

    @Test
    func `reads every section`() throws {
        let config = try ConfigSchema.config(from: Self.filledFile)

        #expect(config.clickInWindow.description == "cmd+1")
        #expect(config.rightClickInWindow.description == "cmd+2")
        #expect(config.appMenus.description == "cmd+3")
        #expect(config.statusIcons.description == "cmd+4")
        #expect(String(config.hintCharacters) == "qwertyui")
        #expect(config.disabledApps == ["com.apple.Finder"])
        #expect(config.launchAtLogin)
    }

    @Test
    func `keeps the default for a key the file omits`() throws {
        let config = try ConfigSchema.config(from: "[startup]\nlaunch_at_login = true\n")

        #expect(config.launchAtLogin)
        #expect(config.clickInWindow == HintjumpConfig.default.clickInWindow)
        #expect(String(config.hintCharacters) == String(HintjumpConfig.default.hintCharacters))
    }

    @Test
    func `keeps the defaults for an empty file`() throws {
        #expect(try ConfigSchema.config(from: "") == HintjumpConfig.default)
    }

    @Test(arguments: [
        (
            "[triggers]\nclick_in_window = \"ctrl+shift+space\"\nhotkey_left = \"ctrl+a\"\n",
            "Line 3: unknown key `hotkey_left`",
        ),
        ("[hotkeys]\n", "Line 1: unknown section `[hotkeys]`"),
        (
            "[triggers]\nclick_in_window = true\n",
            "Line 2: `click_in_window` needs a string, not true or false",
        ),
        (
            "[hints]\ncharacters = [\"a\"]\n",
            "Line 2: `characters` needs a string, not an array of strings",
        ),
        (
            "[apps]\ndisabled = \"com.apple.Finder\"\n",
            "Line 2: `disabled` needs an array of strings, not a string",
        ),
        (
            "[startup]\nlaunch_at_login = \"yes\"\n",
            "Line 2: `launch_at_login` needs true or false, not a string",
        ),
        (
            "[triggers]\nclick_in_window = \"space\"\n",
            "Line 2: `space` has no modifier — every trigger needs at least one of ctrl, alt, shift, cmd",
        ),
        (
            "[triggers]\nclick_in_window = \"ctrl+escape\"\n",
            "Line 2: unknown key `escape` — use a letter, a digit, space, return, tab, f1-f12, "
                + "or one of - = [ ] \\ ; ' , . / `",
        ),
        (
            "[triggers]\nclick_in_window = \"hyper+space\"\n",
            "Line 2: unknown modifier `hyper` — use ctrl, alt, shift, or cmd",
        ),
        (
            "[triggers]\nclick_in_window = \"ctrl+ctrl+space\"\n",
            "Line 2: the modifier `ctrl` is repeated",
        ),
        (
            "[triggers]\nclick_in_window = \"ctrl+shift+m\"\napp_menus = \"ctrl+shift+m\"\n",
            "Line 3: `app_menus` uses the same combination as `click_in_window` — "
                + "every trigger needs its own",
        ),
        (
            "[hints]\ncharacters = \"asdfghj1\"\n",
            "Line 2: `1` is not a hint character — use lower-case ASCII letters",
        ),
        (
            "[hints]\ncharacters = \"asdfghjK\"\n",
            "Line 2: `K` is not a hint character — use lower-case ASCII letters",
        ),
        (
            "[hints]\ncharacters = \"asdfghja\"\n",
            "Line 2: the hint character `a` is repeated",
        ),
        (
            "[hints]\ncharacters = \"asdfghj\"\n",
            "Line 2: hints need at least 8 characters, and this has 7",
        ),
    ])
    func `reports the line of every validation error`(text: String, message: String) {
        #expect(performing: {
            _ = try ConfigSchema.config(from: text)
        }, throws: { error in
            (error as? ConfigError)?.message == message
        })
    }

    /// A trigger left at its default can still collide with one the file sets. The
    /// default has no line, so the blame goes to the line the user can actually edit.
    @Test
    func `blames the written trigger when it collides with a defaulted one`() {
        #expect(performing: {
            _ = try ConfigSchema.config(from: "[triggers]\napp_menus = \"ctrl+shift+space\"\n")
        }, throws: { error in
            (error as? ConfigError)?.message
                == "Line 2: `app_menus` uses the same combination as `click_in_window` — "
                + "every trigger needs its own"
        })
    }
}
