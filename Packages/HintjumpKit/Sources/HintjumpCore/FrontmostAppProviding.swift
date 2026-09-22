import Foundation

/// The frontmost application, as a value Core can reason about.
///
/// A port answers in types Core owns, never in the OS type the adapter used
/// (`NSRunningApplication` here): that is what keeps Core testable with a fake and
/// free of AppKit.
public struct FrontmostApp: Equatable, Sendable {
    /// The application's display name.
    public let name: String
    /// Its bundle identifier, when it has one — some processes do not.
    public let bundleIdentifier: String?
    /// Its process identifier, when the adapter knows it — what a read of its
    /// accessibility tree is addressed to (``AccessibilityTreeReading``). Optional so a
    /// value built without one (a test, a caller that only shows a name) stays valid;
    /// the hint session treats a missing pid as nothing to read.
    public let processIdentifier: pid_t?

    public init(name: String, bundleIdentifier: String? = nil, processIdentifier: pid_t? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

/// A port: "which application is frontmost right now?", asked in Core's own vocabulary.
///
/// This is the template's worked example of the ports-and-adapters boundary
/// (`docs/architecture.md`). Core declares the protocol, `HintjumpPlatform` holds the
/// adapter that answers it with `NSWorkspace`, tests substitute a fake, and `App/` —
/// the composition root — decides which one a view model gets. Nothing below `App/`
/// knows which implementation it is talking to.
///
/// Ports are `Sendable` and take and return value types, so an adapter can be handed
/// across actors and a Core caller never has to reason about the OS object behind it.
///
/// This one is deliberately **pull-style**: it answers with a snapshot of the moment it
/// is asked and pushes nothing, so a caller that wants a current answer asks again (the
/// app does so whenever its scene becomes active). Live updates — following every app
/// switch, not just its own activations — are the second, observing port's job,
/// ``FrontmostAppObserving``, whose adapter subscribes to `NSWorkspace`'s activation
/// notifications; this one is not turned into a publisher.
public protocol FrontmostAppProviding: Sendable {
    /// The application frontmost at the moment of the call, or `nil` when there is none
    /// or the OS declines to say (a sandboxed or background process may get no answer).
    func currentFrontmostApp() -> FrontmostApp?
}
