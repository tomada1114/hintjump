import Observation

/// Observable presentation state over a ``FrontmostAppProviding`` port.
///
/// The Core half of the worked example: it holds the port, not an adapter, so
/// `MyAppCoreTests` drives it with a fake and `App/` hands it the `NSWorkspace`-backed
/// adapter from `MyAppPlatform`. Everything a reader can observe — including the
/// "nothing is frontmost" wording — is decided here, where the coverage floor sees it.
@MainActor
@Observable
public final class FrontmostAppViewModel {
    /// Shown when the port has no answer, before the first ``refresh()`` or after one
    /// that came back empty.
    public static let unavailableDisplayName = "—"

    /// The last answer the port gave, or `nil` before the first ``refresh()``.
    public private(set) var frontmostApp: FrontmostApp?

    private let provider: any FrontmostAppProviding

    /// What to render for the current answer.
    public var displayName: String {
        frontmostApp?.name ?? Self.unavailableDisplayName
    }

    /// Creates the view model over `provider`. Asking the OS in an initializer would
    /// make construction a side effect, so nothing is read until ``refresh()``.
    public init(provider: any FrontmostAppProviding) {
        self.provider = provider
    }

    /// Asks the port again and publishes whatever it answered, `nil` included.
    ///
    /// Nothing calls this for you: ``FrontmostAppProviding`` is a pull-style port, so
    /// state here is only as fresh as the last caller made it. The app refreshes when
    /// its scene becomes active; a live-updating app would observe an OS notification
    /// through a second port rather than poll this one.
    public func refresh() {
        frontmostApp = provider.currentFrontmostApp()
    }
}
