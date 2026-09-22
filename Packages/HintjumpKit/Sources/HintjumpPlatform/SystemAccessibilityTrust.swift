@preconcurrency import ApplicationServices
import HintjumpCore

/// The `ApplicationServices`-backed adapter for ``HintjumpCore/AccessibilityTrustChecking``.
///
/// Copied from `.agents/skills/integrating-system-apis/references/tcc-permissions.md` ›
/// "Checking and prompting": `AXIsProcessTrusted()` is the check with no side effect,
/// `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` is the check *and*
/// the prompt. `@preconcurrency import` is for `kAXTrustedCheckOptionPrompt`, which Swift 6
/// sees as shared mutable state.
public struct SystemAccessibilityTrust: AccessibilityTrustChecking {
    /// The key `AXIsProcessTrustedWithOptions` reads to decide whether to prompt.
    private static let promptOption = kAXTrustedCheckOptionPrompt.takeUnretainedValue()

    /// Whether the grant is held right now — cheap, and the only honest way to know,
    /// since macOS reports a new grant through no callback at all.
    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public init() {
        // Stateless: the OS holds the answer.
    }

    /// Shows the system's "open Privacy & Security" prompt.
    ///
    /// The return value is deliberately dropped: it answers for the moment *before* the
    /// user reacted, so a caller that believed it would report "not trusted" forever.
    /// Ask ``isTrusted`` again later instead.
    public func requestTrust() {
        _ = AXIsProcessTrustedWithOptions([Self.promptOption: true] as CFDictionary)
    }
}
