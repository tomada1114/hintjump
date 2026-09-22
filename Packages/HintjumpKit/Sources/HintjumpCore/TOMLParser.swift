/// The recursive-descent parser behind ``TOMLSubset/parse(_:)``.
///
/// A `struct` with a mutating cursor rather than a class: the parse is a single
/// linear pass and nothing outlives it.
struct TOMLParser {
    var scanner: TOMLScanner
    private var tables: [TOMLTable] = []
    private var currentName: String?
    private var currentLine = 0
    private var currentEntries: [TOMLEntry] = []

    init(source: TOMLSource) {
        scanner = TOMLScanner(source: source)
    }

    /// Whether `character` ends the name being read.
    private static func endsName(_ character: Character, terminator: Character) -> Bool {
        character == terminator || character == " " || character == "\t"
    }

    mutating func parseDocument() throws(ConfigError) -> TOMLDocument {
        while !scanner.isAtEnd {
            scanner.skipSpaces()
            if scanner.isAtEndOfContent {
                scanner.advanceLine()
                continue
            }
            if scanner.current == "[" {
                try startTable()
            } else {
                try appendEntry()
            }
            try finishLine()
        }
        closeTable()
        return TOMLDocument(tables: tables)
    }

    /// Ends the current table and starts the one whose header is under the cursor.
    private mutating func startTable() throws(ConfigError) {
        let line = scanner.lineNumber
        scanner.advance()
        let name = try parseName(terminator: "]", what: "section name")
        guard scanner.current == "]" else {
            throw scanner.error("unterminated section header — expected `]`")
        }
        scanner.advance()
        let isDuplicate = tables.contains { $0.name == name } || currentName == name
        guard !isDuplicate else {
            throw ConfigError(line: line, reason: "duplicate section `[\(name)]`")
        }
        closeTable()
        currentName = name
        currentLine = line
    }

    private mutating func closeTable() {
        guard let currentName else {
            return
        }
        tables.append(TOMLTable(name: currentName, line: currentLine, entries: currentEntries))
        self.currentName = nil
        currentEntries = []
    }

    /// Reads one `key = value` under the open section.
    private mutating func appendEntry() throws(ConfigError) {
        let line = scanner.lineNumber
        let key = try parseName(terminator: "=", what: "key")
        guard currentName != nil else {
            throw ConfigError(
                line: line,
                reason: "key `\(key)` is outside any section — every key belongs under a `[section]`",
            )
        }
        guard !currentEntries.contains(where: { $0.key == key }) else {
            throw ConfigError(line: line, reason: "duplicate key `\(key)`")
        }
        scanner.skipSpaces()
        guard scanner.current == "=" else {
            throw scanner.error("expected `=` after the key `\(key)`")
        }
        scanner.advance()
        scanner.skipSpaces()
        let start = scanner.offset
        let value = try parseValue()
        currentEntries.append(
            TOMLEntry(key: key, value: value, line: line, valueRange: start ..< scanner.offset),
        )
    }

    /// Reads an ASCII `[a-z0-9_]` name up to `terminator` or a space.
    private mutating func parseName(
        terminator: Character,
        what: String,
    ) throws(ConfigError) -> String {
        scanner.skipSpaces()
        var name = ""
        while let character = scanner.current, !Self.endsName(character, terminator: terminator) {
            name.append(character)
            scanner.advance()
        }
        guard !name.isEmpty else {
            throw scanner.error("expected \(what)")
        }
        guard name.allSatisfy({ $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }) else {
            throw scanner
                .error("invalid \(what) `\(name)` — use lower-case letters, digits, and `_`")
        }
        scanner.skipSpaces()
        return name
    }

    /// Rejects anything after a header or a value other than a comment.
    private mutating func finishLine() throws(ConfigError) {
        scanner.skipSpaces()
        guard scanner.isAtEndOfContent else {
            throw scanner.error("unexpected text after the value")
        }
        scanner.advanceLine()
    }
}
