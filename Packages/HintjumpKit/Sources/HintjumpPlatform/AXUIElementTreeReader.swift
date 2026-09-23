import AppKit
import ApplicationServices
import HintjumpCore

/// The Accessibility-API-backed adapter for ``HintjumpCore/AccessibilityTreeReading``.
///
/// Translation and nothing else: it walks another process's `AXUIElement` graph and
/// collapses every node into an ``HintjumpCore/ElementSnapshot`` before anything leaves
/// this file. There is no role filter and no "is this clickable?" here — that is a
/// decision, and decisions live in `HintjumpCore` where the coverage floor sees them
/// (`docs/architecture.md` › Ports and adapters).
///
/// Every `AXUIElement` stays inside a `@MainActor` method, so no non-`Sendable` OS
/// object ever crosses an isolation boundary (the `integrating-system-apis` skill,
/// rule 1). Nothing is retained between calls: each read is a fresh snapshot, matching
/// the pull-style contract of the port.
///
/// Reading another application's tree needs the Accessibility permission, which macOS
/// holds against the *process*, so a command-line tool inherits the grant of the
/// terminal that launched it (`Tools/hintjump-probe/README.md`).
public struct AXUIElementTreeReader: AccessibilityTreeReading {
    /// The undocumented attribute Chromium and Electron applications watch for.
    static let manualAccessibilityAttribute = "AXManualAccessibility"

    public init() {
        // Stateless: the Accessibility API is the whole dependency.
    }

    /// Reads `scope` of `pid`, no deeper than `maxDepth`, and returns it as values, with
    /// what the read cost.
    ///
    /// The clock starts at the first Accessibility call and stops after the last, so the
    /// duration measures the OS round trips a strategy makes and not this process's own
    /// bookkeeping. A single element's attribute never fails the read: an attribute the
    /// application will not answer for is left `nil`, its actions empty, and `isEnabled`
    /// `true`. Only the root read can throw.
    @MainActor
    public func readTree(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
        maxDepth: Int?,
    ) throws -> TreeSnapshot {
        guard AXIsProcessTrusted() else {
            throw AccessibilityReadError.notTrusted
        }
        guard Self.isRunning(pid) else {
            throw AccessibilityReadError.noSuchProcess(pid)
        }

        let clock = ContinuousClock()
        let start = clock.now
        let application = AXUIElementCreateApplication(pid)
        let root = try Self.root(of: application, scope: scope, pid: pid)
        let elements = Self.walk(from: root, strategy: strategy, maxDepth: maxDepth)
        let readDuration = clock.now - start

        AppLog.accessibility.debug(
            """
            read tree pid=\(pid, privacy: .public) scope=\(scope.rawValue, privacy: .public) \
            strategy=\(strategy.rawValue, privacy: .public) \
            maxDepth=\(maxDepth.map(String.init) ?? "none", privacy: .public) \
            elements=\(elements.count, privacy: .public) \
            duration=\(readDuration.milliseconds, privacy: .public)ms
            """,
        )

        return TreeSnapshot(
            bundleIdentifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
            pid: pid,
            scope: scope,
            strategy: strategy,
            elements: elements,
            readDuration: readDuration,
        )
    }

    /// Reads the whole tree under `scope`: ``readTree(pid:scope:strategy:maxDepth:)``
    /// with no depth limit, so a caller that holds this adapter directly — the probe, a
    /// local-machine test — need not name the limit it does not want.
    @MainActor
    public func readTree(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
    ) throws -> TreeSnapshot {
        try readTree(pid: pid, scope: scope, strategy: strategy, maxDepth: nil)
    }

    /// Sets `AXManualAccessibility` on the application element of `pid`.
    ///
    /// Undocumented by Apple and the only switch Chromium and Electron applications
    /// watch for: until it is set, they answer with an empty tree. An application that
    /// does not watch for it reports the attribute as unsupported, which surfaces as
    /// ``HintjumpCore/AccessibilityReadError/attributeUnsupported(_:)`` — "this one needs
    /// no waking" is an answer, and a caller may go on reading.
    @MainActor
    public func enableManualAccessibility(pid: pid_t) throws {
        guard AXIsProcessTrusted() else {
            throw AccessibilityReadError.notTrusted
        }
        guard Self.isRunning(pid) else {
            throw AccessibilityReadError.noSuchProcess(pid)
        }

        let attribute = Self.manualAccessibilityAttribute
        let application = AXUIElementCreateApplication(pid)
        let error = AXUIElementSetAttributeValue(application, attribute as CFString, kCFBooleanTrue)
        guard error == .success else {
            throw Self.readError(error, attribute: attribute, pid: pid)
        }
    }
}

/// Finding the root of a read, and naming what went wrong when there is none.
extension AXUIElementTreeReader {
    /// Whether a process with this pid exists, asked without the Accessibility API.
    ///
    /// `kill(pid, 0)` sends no signal; it only performs the permission and existence
    /// checks. `EPERM` means the process exists and belongs to somebody else, which is
    /// still "running", so only `ESRCH` answers no.
    static func isRunning(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno != ESRCH
    }

    /// The element a walk starts from, per scope.
    ///
    /// `.application` needs no Accessibility call: `AXUIElementCreateApplication` always
    /// answers, even for a process that will never talk to us. `.focusedWindow` and
    /// `.menuBar` ask the application for an attribute and can therefore fail — an
    /// application with no window answers nothing for `AXFocusedWindow`, which is
    /// ``HintjumpCore/AccessibilityReadError/attributeUnsupported(_:)`` and not a broken
    /// adapter. `.popUpMenu` is found by a hit test instead (``popUpMenu(of:)``), and
    /// answers the same error when there is no menu to find.
    static func root(
        of application: AXUIElement,
        scope: ReadScope,
        pid: pid_t,
    ) throws -> AXUIElement {
        switch scope {
        case .application:
            application

        case .focusedWindow:
            try element(kAXFocusedWindowAttribute as String, of: application, pid: pid)

        case .menuBar:
            try element(kAXMenuBarAttribute as String, of: application, pid: pid)

        case .popUpMenu:
            try popUpMenu(of: pid)
        }
    }

    /// Translates an `AXError` into the port's vocabulary.
    ///
    /// `apiDisabled` is how the Accessibility API says "this process is not trusted",
    /// so it becomes ``HintjumpCore/AccessibilityReadError/notTrusted`` rather than an
    /// opaque code. `invalidUIElement` and `cannotComplete` are ambiguous — a dead
    /// process and a wedged live one report the same thing — so the process is asked
    /// again before the error is named.
    static func readError(
        _ error: AXError,
        attribute: String,
        pid: pid_t,
    ) -> AccessibilityReadError {
        switch error {
        case .apiDisabled:
            .notTrusted

        case .attributeUnsupported, .noValue:
            .attributeUnsupported(attribute)

        case .invalidUIElement, .cannotComplete:
            if isRunning(pid) {
                .failed(code: error.rawValue)
            } else {
                .noSuchProcess(pid)
            }

        default:
            .failed(code: error.rawValue)
        }
    }

    /// `attribute` of `element`, when its value is itself an element; the failure
    /// translated by ``readError(_:attribute:pid:)`` otherwise.
    static func element(
        _ attribute: String,
        of element: AXUIElement,
        pid: pid_t,
    ) throws -> AXUIElement {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            throw readError(error, attribute: attribute, pid: pid)
        }
        // `unsafeDowncast` rather than `as?`: Swift rejects a conditional cast to a Core
        // Foundation type as one that can never fail, and `as!` is banned here. The
        // `CFGetTypeID` guard is the check the cast would otherwise do, and an attribute
        // that answered with something other than an element is an unsupported one.
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw AccessibilityReadError.attributeUnsupported(attribute)
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

extension Duration {
    /// This duration in milliseconds.
    ///
    /// Divided by a one-millisecond `Duration` rather than scaled from `components`:
    /// the standard library owns the arithmetic, and no conversion factor has to be
    /// written down as a literal.
    var milliseconds: Double {
        self / .milliseconds(1)
    }
}
