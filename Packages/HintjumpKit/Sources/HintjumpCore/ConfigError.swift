/// A problem with the configuration file, always attributed to a line.
///
/// One error type covers both halves of reading the file — the grammar
/// (``TOMLSubset``) and the schema (``HintjumpConfig``) — because the Status window
/// shows them in the same place and a user editing the file does not care which half
/// objected. ``message`` is that rendering and is part of the contract:
/// `Line 12: unknown key `hotkey_left``.
///
/// Reading stops at the first error rather than collecting every one: a single
/// mistake — an unclosed bracket, a renamed section — usually makes the rest of the
/// file nonsense, so a list of errors would mostly be noise derived from the first.
public struct ConfigError: Error, Equatable, Sendable {
    /// The 1-based line the problem is on.
    public let line: Int
    /// What is wrong, phrased for the person editing the file, with no line prefix.
    public let reason: String

    /// The one-line rendering the Status window shows.
    public var message: String {
        "Line \(line): \(reason)"
    }

    public init(line: Int, reason: String) {
        self.line = line
        self.reason = reason
    }
}
