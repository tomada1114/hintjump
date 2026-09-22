/// Rewrites `[apps] disabled = [...]` in place, leaving every other byte of the file
/// alone.
///
/// The narrowest possible writer, on purpose: "Disable in <App>" has to edit a file a
/// person wrote and keep their comments, their spacing, and their key order
/// (`docs/decisions.md` › "Config file: a hand-written TOML subset, one path, one
/// write-back"). Re-serialising the whole document from ``HintjumpConfig`` would lose
/// all three, so the rewrite replaces exactly the character span the parser recorded
/// for that one value and splices the original text back around it.
enum DisabledAppsRewriter {
    /// `text` with the disabled list replaced by `bundleIDs`.
    ///
    /// The `[apps]` section, or a `disabled` key inside it, may be missing from a file
    /// a user trimmed; the key's line is appended to the section, and the section to
    /// the file, rather than failing an action the user asked for.
    static func rewrite(
        _ text: String,
        disabled bundleIDs: [String],
    ) throws(ConfigError) -> String {
        let source = TOMLSource(text)
        var parser = TOMLParser(source: source)
        let document = try parser.parseDocument()
        let rendered = render(bundleIDs)
        guard let table = document.table(ConfigSchema.appsSection) else {
            return appendingSection(to: text, rendered: rendered)
        }
        guard let entry = table.entry(ConfigSchema.disabled) else {
            return appendingKey(source: source, table: table, rendered: rendered)
        }
        return source.text(in: 0 ..< entry.valueRange.lowerBound)
            + rendered
            + source.text(in: entry.valueRange.upperBound ..< source.characters.count)
    }

    /// The array as this writer spells it: `[]`, or `["a", "b"]`.
    static func render(_ bundleIDs: [String]) -> String {
        guard !bundleIDs.isEmpty else {
            return "[]"
        }
        let escaped = bundleIDs.map { bundleID in
            var quoted = "\""
            for character in bundleID {
                if character == "\\" || character == "\"" { quoted.append("\\") }
                quoted.append(character)
            }
            return quoted + "\""
        }
        return "[" + escaped.joined(separator: ", ") + "]"
    }

    private static func appendingSection(to text: String, rendered: String) -> String {
        let separator = text.isEmpty || text.hasSuffix("\n") ? "" : "\n"
        return text + separator + "\n[\(ConfigSchema.appsSection)]\n"
            + "\(ConfigSchema.disabled) = \(rendered)\n"
    }

    /// Inserts the key at the end of an existing `[apps]` section.
    private static func appendingKey(
        source: TOMLSource,
        table: TOMLTable,
        rendered: String,
    ) -> String {
        let insertion = table.entries.last.map(\.valueRange.upperBound)
            ?? source.lines[table.line - 1].upperBound
        return source.text(in: 0 ..< insertion)
            + "\n\(ConfigSchema.disabled) = \(rendered)"
            + source.text(in: insertion ..< source.characters.count)
    }
}
