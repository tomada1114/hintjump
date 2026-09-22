@testable import HintjumpCore
import Testing

/// The grammar of the accepted TOML subset, and every way it refuses a line.
///
/// The refusals are tested by their full ``ConfigError/message``, line included: the
/// line number is the feature — it is what the Status window shows a user who has to
/// find the mistake in their own file.
@Suite("TOML subset grammar")
struct TOMLSubsetTests {
    @Test
    func `parses sections, comments, strings, arrays, and booleans`() throws {
        let document = try TOMLSubset.parse("""
        # a leading comment

        [triggers]
        click_in_window = "ctrl+shift+space"  # trailing comment

        [apps]
        disabled = ["com.apple.Finder", "com.apple.Safari"]

        [startup]
        launch_at_login = true
        """)

        #expect(document.tables.map(\.name) == ["triggers", "apps", "startup"])
        #expect(document.table("triggers")?.line == 3)
        #expect(
            document.table("triggers")?.entry("click_in_window")?.value
                == .string("ctrl+shift+space"),
        )
        #expect(document.table("triggers")?.entry("click_in_window")?.line == 4)
        #expect(
            document.table("apps")?.entry("disabled")?.value
                == .stringArray(["com.apple.Finder", "com.apple.Safari"]),
        )
        #expect(document.table("startup")?.entry("launch_at_login")?.value == .boolean(true))
    }

    @Test
    func `parses an empty file as no tables`() throws {
        #expect(try TOMLSubset.parse("").tables.isEmpty)
        #expect(try TOMLSubset.parse("# just a comment\n\n").tables.isEmpty)
    }

    @Test
    func `parses a section with no entries`() throws {
        let document = try TOMLSubset.parse("[apps]\n")

        #expect(document.table("apps")?.entries.isEmpty == true)
    }

    @Test
    func `parses an array that spans lines and ends with a comma`() throws {
        let document = try TOMLSubset.parse("""
        [apps]
        disabled = [
            "one",   # why this one
            "two",
        ]
        """)

        #expect(document.table("apps")?.entry("disabled")?.value == .stringArray(["one", "two"]))
    }

    @Test
    func `parses an empty array and unusual spacing`() throws {
        let document = try TOMLSubset.parse("[apps]\n   disabled   =   [ ]\n")

        #expect(document.table("apps")?.entry("disabled")?.value == .stringArray([]))
    }

    @Test
    func `unescapes a quote and a backslash, and nothing else`() throws {
        let document = try TOMLSubset.parse(#"""
        [hints]
        characters = "a\"b\\c"
        """#)

        #expect(document.table("hints")?.entry("characters")?.value == .string(#"a"b\c"#))
    }

    @Test
    func `treats a boolean-looking string as a string`() throws {
        let document = try TOMLSubset.parse("[startup]\nlaunch_at_login = \"true\"\n")

        #expect(document.table("startup")?.entry("launch_at_login")?.value == .string("true"))
    }

    /// Every refusal, as the line-numbered message a user reads. The `text` of each
    /// case is a whole file so the reported line can be counted by eye.
    @Test(arguments: [
        (
            "[triggers]\nkey = 12\n",
            "Line 2: unsupported value — this file accepts a \"string\", an array of strings, or true/false",
        ),
        (
            "[triggers]\nkey = 'single'\n",
            "Line 2: unsupported value — this file accepts a \"string\", an array of strings, or true/false",
        ),
        (
            "[a]\nkey = \"\"\"multi\"\"\"\n",
            "Line 2: unexpected text after the value",
        ),
        ("[a]\nkey = \"unclosed\n", "Line 2: unterminated string"),
        ("[a]\nkey = \"trailing backslash \\", "Line 2: unterminated string"),
        (
            "[a]\nkey = \"bad \\n escape\"\n",
            "Line 2: invalid escape `\\n` — only `\\\"` and `\\\\` are supported",
        ),
        ("[a]\nlist = [\"one\"\n", "Line 2: unterminated array — expected `]`"),
        ("[a]\nlist = [1]\n", "Line 2: an array may only hold \"strings\""),
        ("[a]\nlist = [\"one\" \"two\"]\n", "Line 2: expected `,` or `]` in the array"),
        ("[a]\nkey = \"one\" extra\n", "Line 2: unexpected text after the value"),
        ("[a]\nkey =\n", "Line 2: expected a value after `=`"),
        ("[a]\nkey \"one\"\n", "Line 2: expected `=` after the key `key`"),
        (
            "[a]\na.b = \"one\"\n",
            "Line 2: invalid key `a.b` — use lower-case letters, digits, and `_`",
        ),
        (
            "[a]\nKey = \"one\"\n",
            "Line 2: invalid key `Key` — use lower-case letters, digits, and `_`",
        ),
        ("[a.b]\n", "Line 1: invalid section name `a.b` — use lower-case letters, digits, and `_`"),
        ("[a\n", "Line 1: unterminated section header — expected `]`"),
        ("[]\n", "Line 1: expected section name"),
        ("[a]\n[a]\n", "Line 2: duplicate section `[a]`"),
        ("[a]\nkey = \"one\"\nkey = \"two\"\n", "Line 3: duplicate key `key`"),
        (
            "key = \"one\"\n",
            "Line 1: key `key` is outside any section — every key belongs under a `[section]`",
        ),
    ])
    func `reports the line of every refusal`(text: String, message: String) {
        #expect(performing: {
            _ = try TOMLSubset.parse(text)
        }, throws: { error in
            (error as? ConfigError)?.message == message
        })
    }
}
