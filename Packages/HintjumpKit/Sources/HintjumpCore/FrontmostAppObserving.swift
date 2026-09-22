/// A port: "tell me every time another application becomes frontmost", in Core's own
/// vocabulary.
///
/// The observing counterpart ``FrontmostAppProviding`` anticipates: that port answers
/// "who is frontmost now?" when asked, and this one pushes each switch as it happens,
/// which is what ``DisabledAppsPolicy`` needs to hand a disabled app its trigger keys
/// back the moment it comes forward. The pull port stays as it is; the two are answered
/// by separate adapters.
///
/// `@MainActor` because the workspace notification it is built on is delivered on the
/// main thread and every consumer is main-actor state — stating that once here means no
/// adapter has to justify an isolation hop of its own.
@MainActor
public protocol FrontmostAppObserving: Sendable {
    /// Calls `handler` with the application that became frontmost, on every switch from
    /// now until ``stopObserving()``.
    ///
    /// A second call replaces the first handler rather than adding another, so starting
    /// twice never delivers a switch twice.
    func startObserving(_ handler: @escaping @MainActor (FrontmostApp) -> Void)

    /// Stops delivering switches. Idempotent: calling it while not observing does
    /// nothing.
    func stopObserving()
}
