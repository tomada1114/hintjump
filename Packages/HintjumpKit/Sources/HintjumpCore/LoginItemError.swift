/// Why the OS refused to register or unregister the login item.
///
/// A value rather than the OS error, so Core can compare and log it: ``code`` is the
/// OS's error code, safe to log in the clear, and ``reason`` is its description.
public struct LoginItemError: Error, Equatable, Sendable {
    /// The OS's error code — e.g. `SMAppService`'s "invalid signature" or "operation
    /// not permitted".
    public let code: Int
    /// The OS's description of the failure, for a log line.
    public let reason: String

    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }
}
