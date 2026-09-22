/// The hand-written reader for the documented TOML subset.
///
/// Hand-written rather than a dependency because two of its properties are load-bearing
/// and neither is guaranteed by a general decoder: every error names its line, for the
/// Status window, and every value's character span is recorded, so "Disable in <App>"
/// can rewrite one array without disturbing the user's comments
/// (`docs/decisions.md` › "Config file: a hand-written TOML subset, one path, one
/// write-back").
///
/// What it accepts, and nothing else:
/// - `#` comments, whole-line or trailing
/// - `[section]` headers; keys and section names are ASCII `[a-z0-9_]`
/// - `key = "string"`, with `\"` and `\\` as the only escapes
/// - `key = ["a", "b"]`, which may span lines and may end with a trailing comma
/// - `key = true` / `key = false`
///
/// Anything else — a number, a dotted key, an inline table, a multi-line string, a
/// key outside any section, a repeated key or section — is a ``ConfigError`` naming
/// the line.
public enum TOMLSubset {
    /// Parses `text`, or throws the first problem with it.
    public static func parse(_ text: String) throws(ConfigError) -> TOMLDocument {
        var parser = TOMLParser(source: TOMLSource(text))
        return try parser.parseDocument()
    }
}
