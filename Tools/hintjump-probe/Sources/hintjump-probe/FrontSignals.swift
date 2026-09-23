import AppKit

/// The application `front` reads: the one `--app` names, or whichever is frontmost now.
struct FrontTarget: Equatable {
    let bundleIdentifier: String?
    let pid: pid_t

    /// `--app`'s first running instance, or `NSWorkspace`'s frontmost application —
    /// asked afresh on every call, so a watch follows the person from app to app.
    /// `nil` when `--app` is not running or nothing is frontmost.
    @MainActor
    static func resolve(bundleIdentifier: String?) -> Self? {
        let application = bundleIdentifier.map { named in
            NSRunningApplication.runningApplications(withBundleIdentifier: named).first
        } ?? NSWorkspace.shared.frontmostApplication
        return application.map { running in
            Self(bundleIdentifier: running.bundleIdentifier, pid: running.processIdentifier)
        }
    }
}

/// What one window element says about itself.
struct WindowSignal {
    let roleAndSubrole: String
    let subrole: String?
    let title: String?
    let frame: CGRect?
    /// `AXMain` and `AXModal`; `false` also when the window does not report them.
    let isMain: Bool
    let isModal: Bool

    /// One line's fields: `role/subrole`, main, modal, frame, title.
    var fields: String {
        """
        role=\(roleAndSubrole) main=\(isMain) modal=\(isModal) frame=\(formatted(frame)) \
        title=\(quoted(title))
        """
    }

    init(_ window: AXUIElement) {
        roleAndSubrole = AXRaw.roleAndSubrole(of: window)
        subrole = AXRaw.string(kAXSubroleAttribute, of: window)
        title = AXRaw.string(kAXTitleAttribute, of: window)
        frame = AXRaw.frame(of: window)
        isMain = AXRaw.isTrue(kAXMainAttribute, of: window)
        isModal = AXRaw.isTrue(kAXModalAttribute, of: window)
    }
}

/// The signals #9 asks `front` for, read without walking any tree — cheap enough to
/// take twice a second, which is what lets a watch notice the moment something opens.
struct FrontSignals {
    let target: FrontTarget?
    /// The pid the system-wide element reports as focused. It can differ from
    /// `NSWorkspace`'s frontmost application — a non-activating panel takes focus
    /// without becoming frontmost — which is why both are printed.
    let axFocusedApplication: pid_t?
    /// `role/subrole` of the application's `AXFocusedUIElement`.
    let focusedElement: String?
    let focusedWindow: WindowSignal?
    let windows: [WindowSignal]
    let menus: MenuSignals
    let serverWindows: [WindowServerWindow]
    /// The frontmost application's pop-up-menu-level windows, front to back — the
    /// context-menu signal, which nothing above carries. Only their presence is read
    /// here; the menu inside is read through the adapter when a snapshot is printed.
    let popups: [WindowServerWindow]

    /// One line that changes exactly when one of the signals does, so a watch prints a
    /// snapshot only then. Titles and frames are left out on purpose: a window that
    /// scrolls or retitles is not a new case.
    var signature: String {
        let front = target.map { "\($0.bundleIdentifier ?? "-"):\($0.pid)" } ?? "none"
        let menuOwners = menus.openMenus.map { "\($0.via)@\($0.pid.map(String.init) ?? "-")" }
        let selected = menus.selections.map { "\($0.bar):\(quoted($0.title ?? $0.label))" }
        let fields = [
            "front=\(front)",
            "axFocusedApp=\(axFocusedApplication.map(String.init) ?? "-")",
            "focusedWindow=\(focusedWindow.map { $0.subrole ?? "-" } ?? "none")",
            "windows=[\(windows.map { $0.subrole ?? "-" }.joined(separator: ","))]",
            "menus=[\(menuOwners.joined(separator: ","))]",
            "selected=[\(selected.joined(separator: ","))]",
            "above=[\(Self.counted(serverWindows.map(\.signatureKey)))]",
            "popups=[\(popups.map { "\($0.layer)@\($0.pid)" }.joined(separator: ","))]",
        ]
        return fields.joined(separator: " ")
    }

    /// Reads every signal for `target`, and the window server's list regardless.
    @MainActor
    static func read(_ target: FrontTarget?) -> Self {
        let systemWide = AXUIElementCreateSystemWide()
        let focusedApplication = AXRaw.element(kAXFocusedApplicationAttribute, of: systemWide)
        let onScreen = WindowServerWindow.aboveNormalLayer()
        guard let target else {
            return Self(
                target: nil,
                axFocusedApplication: focusedApplication.flatMap(AXRaw.processIdentifier),
                focusedElement: nil,
                focusedWindow: nil,
                windows: [],
                menus: MenuSignals(openMenus: [], selections: []),
                serverWindows: onScreen,
                popups: [],
            )
        }
        let application = AXUIElementCreateApplication(target.pid)
        return Self(
            target: target,
            axFocusedApplication: focusedApplication.flatMap(AXRaw.processIdentifier),
            focusedElement: AXRaw.element(kAXFocusedUIElementAttribute, of: application)
                .map(AXRaw.roleAndSubrole),
            focusedWindow: AXRaw.element(kAXFocusedWindowAttribute, of: application)
                .map(WindowSignal.init),
            windows: AXRaw.elements(kAXWindowsAttribute, of: application).map(WindowSignal.init),
            menus: MenuSignals.read(from: application),
            serverWindows: onScreen,
            popups: onScreen.filter { window in
                window.layer == WindowServerWindow.popUpMenuLayer && window.pid == target.pid
            },
        )
    }

    /// `a:1x3,b:25` — each distinct key once, sorted, with a count when it repeats, so
    /// the order the window server lists windows in never changes the signature.
    private static func counted(_ keys: [String]) -> String {
        Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
            .sorted { $0.key < $1.key }
            .map { $0.value > 1 ? "\($0.key)x\($0.value)" : $0.key }
            .joined(separator: ",")
    }
}
