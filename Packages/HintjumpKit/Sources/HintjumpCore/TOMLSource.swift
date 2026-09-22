/// The configuration text, indexed by line so a scanner can report line numbers and a
/// rewriter can splice a value back by offset.
///
/// Characters rather than `String.Index`: the offsets the parser records for a value
/// have to survive being handed to ``DisabledAppsRewriter``, and an integer offset into
/// one array is the simplest thing that does. Configuration files are small enough that
/// the copy costs nothing.
struct TOMLSource {
    /// Every character of the original text, in order.
    let characters: [Character]
    /// One half-open offset range per line, covering the line's content: the trailing
    /// `\n` is excluded, and so is a `\r` before it, so a CRLF file tokenizes as a LF
    /// file does while the original bytes stay intact for a rewrite.
    let lines: [Range<Int>]

    init(_ text: String) {
        let all = Array(text)
        var ranges: [Range<Int>] = []
        var start = 0
        for offset in all.indices where all[offset] == "\n" {
            ranges.append(start ..< Self.contentEnd(of: all, from: start, to: offset))
            start = offset + 1
        }
        if start < all.count || ranges.isEmpty {
            ranges.append(start ..< Self.contentEnd(of: all, from: start, to: all.count))
        }
        characters = all
        lines = ranges
    }

    /// `end`, less a single `\r` immediately before it.
    private static func contentEnd(of all: [Character], from start: Int, to end: Int) -> Int {
        end > start && all[end - 1] == "\r" ? end - 1 : end
    }

    /// The text between two offsets, for a rewrite that keeps everything outside them.
    func text(in range: Range<Int>) -> String {
        String(characters[range])
    }
}
