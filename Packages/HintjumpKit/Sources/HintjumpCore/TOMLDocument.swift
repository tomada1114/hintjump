/// A value in the accepted TOML subset.
///
/// Three cases, deliberately: the configuration needs a string, a list of strings, and
/// a flag, and every other TOML value — a number, a date, an inline table, a dotted
/// key — is a parse error naming its line rather than something the schema has to
/// reject later (`docs/decisions.md` › "Config file: a hand-written TOML subset").
public enum TOMLValue: Equatable, Sendable {
    case boolean(Bool)
    case string(String)
    case stringArray([String])

    /// The value's name in an error message, so the schema can say what it found.
    var kindName: String {
        switch self {
        case .boolean:
            "true or false"

        case .string:
            "a string"

        case .stringArray:
            "an array of strings"
        }
    }
}

/// One `key = value` line, with the line it is on and the span its value occupies.
public struct TOMLEntry: Equatable, Sendable {
    public let key: String
    public let value: TOMLValue
    /// The 1-based line the key is on — what an error about this entry reports.
    public let line: Int
    /// The value's character offsets in the original text. ``ConfigRewriter``
    /// replaces exactly this span, which is what keeps every other byte — comments
    /// included — identical.
    let valueRange: Range<Int>
}

/// One `[section]` and the entries under it.
public struct TOMLTable: Equatable, Sendable {
    public let name: String
    /// The 1-based line of the `[section]` header.
    public let line: Int
    public let entries: [TOMLEntry]

    public func entry(_ key: String) -> TOMLEntry? {
        entries.first { $0.key == key }
    }
}

/// A parsed configuration file: tables in the order they appear.
///
/// There is no top-level table: the format requires every key to sit under a section,
/// so a key before the first header is a parse error rather than a fourth shape to
/// model.
public struct TOMLDocument: Equatable, Sendable {
    public let tables: [TOMLTable]

    public func table(_ name: String) -> TOMLTable? {
        tables.first { $0.name == name }
    }
}
