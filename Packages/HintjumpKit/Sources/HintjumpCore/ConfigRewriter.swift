/// Rewrites one key's value in place, leaving every other byte of the file alone.
///
/// The narrowest possible writer, on purpose: every write-back — "Disable in <App>",
/// and each setting the Settings window changes — has to edit a file a person wrote and
/// keep their comments, their spacing, and their key order (`docs/decisions.md` ›
/// "Config file: a hand-written TOML subset, one path, one write-back"). Re-serialising
/// the whole document from ``HintjumpConfig`` would lose all three, so a rewrite
/// replaces exactly the character span the parser recorded for that one value and
/// splices the original text back around it.
enum ConfigRewriter {
    /// `text` with `[section] key` set to `value`.
    ///
    /// The section, or the key inside it, may be missing from a file a user trimmed; the
    /// key's line is appended to the section, and the section to the file, rather than
    /// failing a change the user asked for. A file that does not parse is refused with
    /// its own error, never written over.
    static func rewrite(
        _ text: String,
        section: String,
        key: String,
        value: TOMLValue,
    ) throws(ConfigError) -> String {
        let source = TOMLSource(text)
        var parser = TOMLParser(source: source)
        let document = try parser.parseDocument()
        let line = "\(key) = \(render(value))"
        guard let table = document.table(section) else {
            let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
            return text + separator + "\n[\(section)]\n\(line)\n"
        }
        guard let entry = table.entry(key) else {
            return appending(line, to: table, in: source)
        }
        return source.text(in: 0 ..< entry.valueRange.lowerBound)
            + render(value)
            + source.text(in: entry.valueRange.upperBound ..< source.characters.count)
    }

    /// `text` with every key whose value differs between `old` and `new` rewritten, one
    /// ``rewrite(_:section:key:value:)`` each, in schema order.
    ///
    /// The comparison is between the two configurations' rendered values, not against
    /// the file's own spelling, so a key the change leaves alone keeps whatever way the
    /// user wrote it — `shift+ctrl+s` stays `shift+ctrl+s`. Schema order is what makes
    /// the keys appended to a trimmed file come out in the order the default file uses.
    static func rewrite(
        _ text: String,
        changing old: HintjumpConfig,
        to new: HintjumpConfig,
    ) throws(ConfigError) -> String {
        var rewritten = text
        let changes = zip(ConfigSchema.settings(of: old), ConfigSchema.settings(of: new))
            .filter { $0 != $1 }
            .map(\.1)
        for setting in changes {
            rewritten = try rewrite(
                rewritten,
                section: setting.section,
                key: setting.key,
                value: setting.value,
            )
        }
        return rewritten
    }

    /// The value as this writer spells it: `"text"`, `true`/`false`, `[]`, or
    /// `["a", "b"]`, with `"` and `\` escaped — the only two escapes the subset reads.
    static func render(_ value: TOMLValue) -> String {
        switch value {
        case let .boolean(flag):
            flag ? "true" : "false"

        case let .string(text):
            quoted(text)

        case let .stringArray(texts):
            "[" + texts.map(quoted).joined(separator: ", ") + "]"
        }
    }

    private static func quoted(_ text: String) -> String {
        var quoted = "\""
        for character in text {
            if character == "\\" || character == "\"" { quoted.append("\\") }
            quoted.append(character)
        }
        return quoted + "\""
    }

    /// Inserts `line` at the end of an existing section: after the whole line its last
    /// entry ends on, so a trailing comment stays with that entry.
    private static func appending(
        _ line: String,
        to table: TOMLTable,
        in source: TOMLSource,
    ) -> String {
        let valueEnd = table.entries.last?.valueRange.upperBound
        let lastLine = valueEnd.flatMap { end in
            source.lines.first { $0.lowerBound <= end && end <= $0.upperBound }
        }
        let insertion = (lastLine ?? source.lines[table.line - 1]).upperBound
        return source.text(in: 0 ..< insertion)
            + "\n\(line)"
            + source.text(in: insertion ..< source.characters.count)
    }
}
