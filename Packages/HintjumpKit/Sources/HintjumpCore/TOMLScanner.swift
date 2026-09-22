/// A cursor over ``TOMLSource``: one line at a time, with the absolute offset the
/// parser records for a value it may later have to rewrite in place.
struct TOMLScanner {
    let source: TOMLSource
    /// The 0-based line the cursor is on; equal to the line count once exhausted.
    private(set) var lineIndex = 0
    /// The absolute character offset of the cursor.
    private(set) var offset = 0

    /// The 1-based line number, as an error message spells it.
    var lineNumber: Int {
        lineIndex + 1
    }

    /// Whether every line has been consumed.
    var isAtEnd: Bool {
        lineIndex >= source.lines.count
    }

    /// The character under the cursor, or `nil` at the end of the current line.
    var current: Character? {
        guard !isAtEnd, offset < source.lines[lineIndex].upperBound else {
            return nil
        }
        return source.characters[offset]
    }

    /// Whether the rest of the current line is blank or a comment.
    var isAtEndOfContent: Bool {
        guard let current else {
            return true
        }
        return current == "#"
    }

    init(source: TOMLSource) {
        self.source = source
        offset = source.lines.first?.lowerBound ?? 0
    }

    mutating func advance() {
        offset += 1
    }

    /// Moves to the start of the next line, whatever is left on this one.
    mutating func advanceLine() {
        lineIndex += 1
        offset = isAtEnd ? source.characters.count : source.lines[lineIndex].lowerBound
    }

    mutating func skipSpaces() {
        while let current, current == " " || current == "\t" {
            advance()
        }
    }

    /// Consumes `text` when it is next on this line, and reports whether it did.
    mutating func match(_ text: String) -> Bool {
        let wanted = Array(text)
        let end = offset + wanted.count
        guard !isAtEnd, end <= source.lines[lineIndex].upperBound else {
            return false
        }
        guard Array(source.characters[offset ..< end]) == wanted else {
            return false
        }
        offset = end
        return true
    }

    /// An error attributed to the line the cursor is on.
    ///
    /// Clamped to the last line: a value left unterminated at the end of the file is
    /// noticed with the cursor already past it, and a line number the file does not
    /// have would read as a bug rather than as an instruction.
    func error(_ reason: String) -> ConfigError {
        ConfigError(line: min(lineNumber, source.lines.count), reason: reason)
    }
}
