@testable import HintjumpCore
import Testing

/// The write-back: one key's value replaced, every other byte identical.
///
/// "Byte-identical" is asserted the only way that means anything — by comparing the
/// whole file against the original with just that one span substituted — because the
/// point of the hand-written reader is that a user's comments and spacing survive a
/// write-back (`docs/decisions.md`).
@Suite("Config write-back")
struct ConfigRewriterTests {
    /// A file with comments, unusual spacing, and a key order the app did not write.
    static let messyFile = """
    # my own notes, do not lose these

    [startup]
    launch_at_login   =    true   # I like it this way

    [apps]
    # the ones I keep off
    disabled    =  [ "com.apple.Terminal" ]   # trailing note

    [hints]
    characters = "asdfghjklqwertyuiop"
    # a dangling comment at the end

    """

    /// `text` with `[apps] disabled` replaced by `bundleIDs`.
    static func disabled(_ text: String, _ bundleIDs: [String]) throws -> String {
        try ConfigRewriter.rewrite(
            text,
            section: ConfigSchema.appsSection,
            key: ConfigSchema.disabled,
            value: .stringArray(bundleIDs),
        )
    }

    // MARK: - A string array

    @Test
    func `changes only the array, leaving every other byte intact`() throws {
        let rewritten = try Self.disabled(
            Self.messyFile,
            ["com.apple.Terminal", "com.apple.Safari"],
        )

        let expected = Self.messyFile.replacingOccurrences(
            of: #"[ "com.apple.Terminal" ]"#,
            with: #"["com.apple.Terminal", "com.apple.Safari"]"#,
        )
        #expect(rewritten == expected)
    }

    @Test
    func `rewrites the default file and leaves its comments`() throws {
        let rewritten = try Self.disabled(HintjumpConfig.defaultFileContents, ["com.apple.Finder"])

        #expect(
            rewritten == HintjumpConfig.defaultFileContents.replacingOccurrences(
                of: "disabled = []",
                with: #"disabled = ["com.apple.Finder"]"#,
            ),
        )
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["com.apple.Finder"])
    }

    @Test
    func `empties the array back to the empty brackets`() throws {
        let rewritten = try Self.disabled(Self.messyFile, [])

        #expect(rewritten.contains("disabled    =  []   # trailing note"))
        #expect(try ConfigSchema.config(from: rewritten).disabledApps.isEmpty)
    }

    @Test
    func `replaces an array that spans several lines with a single line`() throws {
        let text = """
        [apps]
        disabled = [
            "one",
            "two",
        ]
        # after

        """

        let rewritten = try Self.disabled(text, ["one"])

        #expect(rewritten == "[apps]\ndisabled = [\"one\"]\n# after\n")
    }

    @Test
    func `escapes a quote and a backslash in a bundle identifier`() throws {
        let rewritten = try Self.disabled("[apps]\ndisabled = []\n", [#"od"d\one"#])

        #expect(rewritten == "[apps]\ndisabled = [\"od\\\"d\\\\one\"]\n")
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == [#"od"d\one"#])
    }

    // MARK: - A string and a boolean

    @Test
    func `replaces a string, keeping the spacing and the comment around it`() throws {
        let rewritten = try ConfigRewriter.rewrite(
            Self.messyFile,
            section: ConfigSchema.hintsSection,
            key: ConfigSchema.characters,
            value: .string("qwertyuiop"),
        )

        #expect(rewritten == Self.messyFile.replacingOccurrences(
            of: #"characters = "asdfghjklqwertyuiop""#,
            with: #"characters = "qwertyuiop""#,
        ))
    }

    @Test
    func `escapes a quote and a backslash in a string`() throws {
        let rewritten = try ConfigRewriter.rewrite(
            "[triggers]\napp_menus = \"ctrl+m\"\n",
            section: ConfigSchema.triggersSection,
            key: ConfigSchema.appMenus,
            value: .string(#"ctrl+\"#),
        )

        #expect(rewritten == "[triggers]\napp_menus = \"ctrl+\\\\\"\n")
        #expect(try TOMLSubset.parse(rewritten).table("triggers")?.entry("app_menus")?
            .value == .string(#"ctrl+\"#))
    }

    @Test(arguments: [true, false])
    func `replaces a boolean, keeping the spacing and the comment around it`(_ value: Bool) throws {
        let rewritten = try ConfigRewriter.rewrite(
            Self.messyFile,
            section: ConfigSchema.startupSection,
            key: ConfigSchema.launchAtLogin,
            value: .boolean(value),
        )

        #expect(rewritten == Self.messyFile.replacingOccurrences(
            of: "launch_at_login   =    true   #",
            with: "launch_at_login   =    \(value)   #",
        ))
    }

    // MARK: - Appending

    @Test
    func `adds the key to an apps section that does not have it`() throws {
        let text = "# notes\n\n[apps]\n"

        let rewritten = try Self.disabled(text, ["one"])

        #expect(rewritten.hasPrefix("# notes\n\n[apps]\n"))
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
    }

    @Test
    func `adds the key after the section's last line, keeping its trailing comment`() throws {
        let text = "[apps]\nfuture = \"x\" # keep\n"

        let rewritten = try Self.disabled(text, ["one"])

        #expect(rewritten == "[apps]\nfuture = \"x\" # keep\ndisabled = [\"one\"]\n")
    }

    @Test
    func `adds a string key after a section's last entry`() throws {
        let text = "[triggers]\nclick_in_window = \"ctrl+shift+space\" # mine\n\n[apps]\n"

        let rewritten = try ConfigRewriter.rewrite(
            text,
            section: ConfigSchema.triggersSection,
            key: ConfigSchema.appMenus,
            value: .string("ctrl+shift+j"),
        )

        #expect(rewritten == """
        [triggers]
        click_in_window = "ctrl+shift+space" # mine
        app_menus = "ctrl+shift+j"

        [apps]

        """)
    }

    @Test
    func `adds the section to a file that does not have it`() throws {
        let text = "[startup]\nlaunch_at_login = true\n"

        let rewritten = try Self.disabled(text, ["one"])

        #expect(rewritten.hasPrefix(text))
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
        #expect(try ConfigSchema.config(from: rewritten).launchAtLogin)
    }

    @Test
    func `adds a boolean's section after a last line with no newline`() throws {
        let rewritten = try ConfigRewriter.rewrite(
            "[apps]\ndisabled = []",
            section: ConfigSchema.startupSection,
            key: ConfigSchema.launchAtLogin,
            value: .boolean(true),
        )

        #expect(rewritten == "[apps]\ndisabled = []\n\n[startup]\nlaunch_at_login = true\n")
    }

    @Test
    func `adds the section to an empty file`() throws {
        let rewritten = try Self.disabled("", ["one"])

        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
    }

    @Test
    func `refuses a file it cannot parse rather than writing over it`() {
        #expect(throws: ConfigError(line: 2, reason: "unterminated array — expected `]`")) {
            _ = try Self.disabled("[apps]\ndisabled = [\n", [])
        }
    }

    // MARK: - Old configuration against new

    @Test
    func `rewrites nothing when the two configurations agree`() throws {
        let rewritten = try ConfigRewriter.rewrite(
            Self.messyFile,
            changing: .default,
            to: .default,
        )

        #expect(rewritten == Self.messyFile)
    }

    @Test
    func `writes every key into an empty file, in schema order, and reads it back`() throws {
        var changed = HintjumpConfig.builtIn
        changed.clickInWindow = try KeyCombination.parse("ctrl+shift+k")
        changed.rightClickInWindow = try KeyCombination.parse("ctrl+alt+k")
        changed.appMenus = try KeyCombination.parse("cmd+shift+m")
        changed.statusIcons = try KeyCombination.parse("ctrl+shift+i")
        changed.hintCharacters = Array("qwertyuiop")
        changed.disabledApps = ["com.apple.Finder"]
        changed.launchAtLogin = true

        let rewritten = try ConfigRewriter.rewrite("", changing: .builtIn, to: changed)

        #expect(rewritten == """

        [triggers]
        click_in_window = "ctrl+shift+k"
        right_click_in_window = "ctrl+alt+k"
        app_menus = "shift+cmd+m"
        status_icons = "ctrl+shift+i"

        [hints]
        characters = "qwertyuiop"

        [apps]
        disabled = ["com.apple.Finder"]

        [startup]
        launch_at_login = true

        """)
        #expect(try ConfigSchema.config(from: rewritten) == changed)
    }
}
