@testable import HintjumpCore
import Testing

/// The write-back: one array's value replaced, every other byte identical.
///
/// "Byte-identical" is asserted the only way that means anything — by comparing the
/// whole file against the original with just that one span substituted — because the
/// point of the hand-written reader is that a user's comments and spacing survive
/// "Disable in <App>" (`docs/decisions.md`).
@Suite("Disabled-apps write-back")
struct DisabledAppsRewriterTests {
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

    @Test
    func `changes only the array, leaving every other byte intact`() throws {
        let rewritten = try DisabledAppsRewriter.rewrite(
            Self.messyFile,
            disabled: ["com.apple.Terminal", "com.apple.Safari"],
        )

        let expected = Self.messyFile.replacingOccurrences(
            of: #"[ "com.apple.Terminal" ]"#,
            with: #"["com.apple.Terminal", "com.apple.Safari"]"#,
        )
        #expect(rewritten == expected)
    }

    @Test
    func `rewrites the default file and leaves its comments`() throws {
        let rewritten = try DisabledAppsRewriter.rewrite(
            HintjumpConfig.defaultFileContents,
            disabled: ["com.apple.Finder"],
        )

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
        let rewritten = try DisabledAppsRewriter.rewrite(Self.messyFile, disabled: [])

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

        let rewritten = try DisabledAppsRewriter.rewrite(text, disabled: ["one"])

        #expect(rewritten == "[apps]\ndisabled = [\"one\"]\n# after\n")
    }

    @Test
    func `escapes a quote and a backslash in a bundle identifier`() throws {
        let rewritten = try DisabledAppsRewriter.rewrite(
            "[apps]\ndisabled = []\n",
            disabled: [#"od"d\one"#],
        )

        #expect(rewritten == "[apps]\ndisabled = [\"od\\\"d\\\\one\"]\n")
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == [#"od"d\one"#])
    }

    @Test
    func `adds the key to an apps section that does not have it`() throws {
        let text = "# notes\n\n[apps]\n"

        let rewritten = try DisabledAppsRewriter.rewrite(text, disabled: ["one"])

        #expect(rewritten.hasPrefix("# notes\n\n[apps]\n"))
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
    }

    @Test
    func `adds the key after the section's last line, keeping its trailing comment`() throws {
        let text = "[apps]\nfuture = \"x\" # keep\n"

        let rewritten = try DisabledAppsRewriter.rewrite(text, disabled: ["one"])

        #expect(rewritten == "[apps]\nfuture = \"x\" # keep\ndisabled = [\"one\"]\n")
    }

    @Test
    func `adds the section to a file that does not have it`() throws {
        let text = "[startup]\nlaunch_at_login = true\n"

        let rewritten = try DisabledAppsRewriter.rewrite(text, disabled: ["one"])

        #expect(rewritten.hasPrefix(text))
        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
        #expect(try ConfigSchema.config(from: rewritten).launchAtLogin)
    }

    @Test
    func `adds the section to an empty file`() throws {
        let rewritten = try DisabledAppsRewriter.rewrite("", disabled: ["one"])

        #expect(try ConfigSchema.config(from: rewritten).disabledApps == ["one"])
    }

    @Test
    func `refuses a file it cannot parse rather than writing over it`() {
        #expect(performing: {
            _ = try DisabledAppsRewriter.rewrite("[apps]\ndisabled = [\n", disabled: [])
        }, throws: { error in
            (error as? ConfigError)?.message == "Line 2: unterminated array — expected `]`"
        })
    }
}
