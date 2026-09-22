import AppKit
import HintjumpCore

extension FrontmostApp {
    /// `application` reduced to the value Core reasons about — the one translation both
    /// ``WorkspaceFrontmostAppProvider`` and ``WorkspaceFrontmostAppObserver`` make.
    ///
    /// A running application with no `localizedName` is dropped rather than given a
    /// made-up one, so Core decides what "unavailable" reads like.
    init?(_ application: NSRunningApplication) {
        guard let name = application.localizedName else {
            return nil
        }
        self.init(
            name: name,
            bundleIdentifier: application.bundleIdentifier,
            processIdentifier: application.processIdentifier,
        )
    }
}
