import AppKit
import HintjumpCore

/// The `NSWorkspace`-backed adapter for ``HintjumpCore/FrontmostAppObserving``.
///
/// One block observer on `NSWorkspace.shared.notificationCenter` for
/// `didActivateApplicationNotification`. Translation only: the notification's
/// `NSRunningApplication` is reduced to a ``HintjumpCore/FrontmostApp`` inside the block,
/// so only that value reaches the handler (`.agents/skills/integrating-system-apis`
/// › "Three rules that never bend", rule 1). What an activation means is
/// ``HintjumpCore/DisabledAppsPolicy``'s decision.
///
/// No refcon and no C callback: the observer token is the only resource, and
/// ``stopObserving()`` removes it.
@MainActor
public final class WorkspaceFrontmostAppObserver: FrontmostAppObserving {
    private var token: (any NSObjectProtocol)?

    public init() {
        // Nothing is observed until startObserving(_:): an observer is a resource, not
        // a constructor.
    }

    /// Adds the one activation observer, replacing any earlier one.
    ///
    /// The block is delivered on `OperationQueue.main`, which runs on the main thread —
    /// the fact `MainActor.assumeIsolated` relies on. An activation whose application
    /// has no name is dropped, as ``WorkspaceFrontmostAppProvider`` drops it.
    public func startObserving(_ handler: @escaping @MainActor (FrontmostApp) -> Void) {
        stopObserving()
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main,
        ) { notification in
            let key = NSWorkspace.applicationUserInfoKey
            guard let application = notification.userInfo?[key] as? NSRunningApplication,
                  let app = FrontmostApp(application)
            else {
                return
            }
            MainActor.assumeIsolated {
                handler(app)
            }
        }
    }

    /// Removes the observer. Idempotent: with none installed it does nothing.
    public func stopObserving() {
        guard let token else {
            return
        }
        NSWorkspace.shared.notificationCenter.removeObserver(token)
        self.token = nil
    }
}
