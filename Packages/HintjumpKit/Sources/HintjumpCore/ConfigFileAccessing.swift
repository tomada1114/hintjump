/// A port: the one configuration file, read and written as text.
///
/// Text rather than a parsed document, and one file rather than a directory, because
/// the whole point of the hand-written reader is that Core owns the parse and the
/// rewrite: an adapter that returned values would have to hold the grammar, and it
/// would be outside the coverage floor (`.claude/rules/testing.md` › Where a test
/// goes). All the adapter does is resolve the path, create the directory, and move
/// bytes.
public protocol ConfigFileAccessing: Sendable {
    /// Where the file is, for a message that tells a user which file to edit.
    var path: String { get }
    /// The file's contents, or `nil` when it does not exist — which is not an error:
    /// ``ConfigStore/load()`` answers an absent file by writing the default.
    func read() throws -> String?
    /// Replaces the file's contents.
    func write(_ text: String) throws
}
