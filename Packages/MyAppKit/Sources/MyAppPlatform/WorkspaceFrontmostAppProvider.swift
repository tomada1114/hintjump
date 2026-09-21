import AppKit
import MyAppCore

/// The `NSWorkspace`-backed adapter for ``MyAppCore/FrontmostAppProviding``.
///
/// The template's worked example of an adapter, and the shape every other one copies:
/// it imports the OS framework Core may not, translates the OS type into Core's value
/// type, and holds no branching domain logic of its own. That is why `MyAppPlatform`
/// sits outside the coverage floor (`scripts/coverage.sh` measures `MyAppCore` only) —
/// a decision that would need a test belongs in Core, behind the port.
public struct WorkspaceFrontmostAppProvider: FrontmostAppProviding {
    public init() {
        // Stateless: NSWorkspace.shared is the whole dependency.
    }

    /// Asks `NSWorkspace` who is frontmost and reduces the answer to a value.
    ///
    /// A snapshot of this instant, not a subscription: the adapter registers for no
    /// notification and keeps no state, matching the pull-style contract of the port
    /// it implements. Live updates would be a separate observing port, not a change
    /// of behavior here.
    ///
    /// `NSWorkspace` answers `nil` when no application is frontmost; a running
    /// application with no `localizedName` is dropped rather than given a made-up one,
    /// so Core decides what "unavailable" reads like.
    public func currentFrontmostApp() -> FrontmostApp? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let name = application.localizedName
        else {
            return nil
        }
        return FrontmostApp(name: name, bundleIdentifier: application.bundleIdentifier)
    }
}
