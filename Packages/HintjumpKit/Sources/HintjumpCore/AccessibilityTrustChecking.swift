/// A port: does this process hold the Accessibility grant, and can it ask for it?
///
/// macOS reports a grant through no callback at all (`.agents/skills/integrating-system-apis/
/// references/tcc-permissions.md` › "The grant arrives with no callback"), so the check and
/// the decision of when to prompt are Core's to own; the adapter in `HintjumpPlatform` does
/// nothing but translate the OS call. The methods are `@MainActor` because the OS call this
/// port fronts (`AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions`) is bound to the main
/// run loop.
@MainActor
public protocol AccessibilityTrustChecking: Sendable {
    /// Whether this process holds the Accessibility grant right now.
    var isTrusted: Bool { get }

    /// Shows the system's "open Privacy & Security" prompt, if it has not already been
    /// shown to this process. Spend this at most once — see
    /// ``AccessibilityGateViewModel/promptIfNeeded()``.
    func requestTrust()
}
