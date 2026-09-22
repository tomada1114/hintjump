/// Value parsing for ``TOMLParser``: the three shapes the subset accepts, and the
/// line-numbered refusal of everything else.
extension TOMLParser {
    /// Reads the value under the cursor, which has already been positioned past the
    /// spaces after `=`. An array may run over several lines; nothing else may.
    mutating func parseValue() throws(ConfigError) -> TOMLValue {
        guard let character = scanner.current else {
            throw scanner.error("expected a value after `=`")
        }
        switch character {
        case "\"":
            return try .string(parseString())

        case "[":
            return try .stringArray(parseStringArray())

        default:
            if scanner.match("true") {
                return .boolean(true)
            }
            if scanner.match("false") {
                return .boolean(false)
            }
            throw scanner.error(
                "unsupported value — this file accepts a \"string\", an array of strings, or true/false",
            )
        }
    }

    /// Reads a `"…"` string, which lives on one line.
    ///
    /// `\"` and `\\` are the only escapes: a configuration file that needs a tab or a
    /// newline inside a value does not exist here, and every unrecognised escape is an
    /// error rather than a silently kept backslash, so a file written against full TOML
    /// is refused out loud.
    mutating func parseString() throws(ConfigError) -> String {
        scanner.advance()
        var value = ""
        while let character = scanner.current {
            switch character {
            case "\"":
                scanner.advance()
                return value

            case "\\":
                scanner.advance()
                guard let escaped = scanner.current else {
                    throw scanner.error("unterminated string")
                }
                guard escaped == "\"" || escaped == "\\" else {
                    throw scanner
                        .error(
                            "invalid escape `\\\(escaped)` — only `\\\"` and `\\\\` are supported",
                        )
                }
                value.append(escaped)
                scanner.advance()

            default:
                value.append(character)
                scanner.advance()
            }
        }
        throw scanner.error("unterminated string")
    }

    /// Reads a `[ "a", "b" ]` array, which may span lines and may end with a comma.
    mutating func parseStringArray() throws(ConfigError) -> [String] {
        scanner.advance()
        var values: [String] = []
        var expectsValue = true
        while true {
            skipArrayWhitespace()
            guard let character = scanner.current else {
                throw scanner.error("unterminated array — expected `]`")
            }
            if character == "]" {
                scanner.advance()
                return values
            }
            guard expectsValue else {
                throw scanner.error("expected `,` or `]` in the array")
            }
            guard character == "\"" else {
                throw scanner.error("an array may only hold \"strings\"")
            }
            try values.append(parseString())
            skipArrayWhitespace()
            if scanner.current == "," {
                scanner.advance()
                expectsValue = true
            } else {
                expectsValue = false
            }
        }
    }

    /// Skips spaces, comments, and line breaks inside an array, stopping at the first
    /// character that means something — or at the end of the file, which the caller
    /// then reports as an unterminated array.
    private mutating func skipArrayWhitespace() {
        while !scanner.isAtEnd {
            scanner.skipSpaces()
            if scanner.isAtEndOfContent {
                scanner.advanceLine()
                continue
            }
            return
        }
    }
}
