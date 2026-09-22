import Foundation
import HintjumpCore
import ServiceManagement

/// The `ServiceManagement`-backed adapter for ``HintjumpCore/LoginItemRegistering``.
///
/// `SMAppService.mainApp` (macOS 13+) is the whole API: `status` to read,
/// `register()`/`unregister()` to change. Translation only — whether to change anything
/// is ``HintjumpCore/ConfigStore``'s decision; what cannot be checked there — that the
/// real service answers what this adapter assumes — is `SMAppServiceLoginItemTests`,
/// run by hand with `just test-local`.
public struct SMAppServiceLoginItem: LoginItemRegistering {
    /// Whether the app is a login item: `.enabled`, or `.requiresApproval` — registered,
    /// but switched off by the user in System Settings › General › Login Items, which
    /// is the user's call to reverse, not a reload's.
    public var isRegistered: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            true

        case .notRegistered, .notFound:
            false

        @unknown default:
            false
        }
    }

    public init() {
        // Stateless: the OS holds the answer.
    }

    /// Registers or unregisters the running app, translating the OS's error into
    /// ``HintjumpCore/LoginItemError`` so Core never sees an `NSError`.
    public func setRegistered(_ enabled: Bool) throws(LoginItemError) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let osError = error as NSError
            throw LoginItemError(code: osError.code, reason: osError.localizedDescription)
        }
    }
}
