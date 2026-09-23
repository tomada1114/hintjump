import ApplicationServices

/// Single-attribute Accessibility reads the probe makes itself, for the signals the
/// adapter's port has no word for: the focused window's subrole, `AXWindows`, whether a
/// menu bar title is selected, which application the system says is focused.
///
/// Kept here rather than in `HintjumpPlatform` on purpose: `front` prints more than the
/// product reads — every `AXWindows` entry, menu-bar selections, the focused element —
/// while `HintjumpPlatform`'s `SystemTopmostContainerProbe` (#48) reads only the signals
/// the targeting rule needs. Every read answers `nil` (or `[]`) for anything the
/// application will not say, so a missing attribute is printed as `-` rather than
/// stopping the probe.
enum AXRaw {
    /// How long one Accessibility call may wait for an application before it gives up,
    /// in seconds. Set once on the system-wide element, which makes it every element's
    /// default: a watch that samples twice a second must not stall six seconds (the
    /// system default) on one application that stopped answering.
    static let messagingTimeout: Float = 1

    /// Applies ``messagingTimeout`` to every element this process creates from now on.
    static func limitMessagingTimeout() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), messagingTimeout)
    }

    private static func value(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value
    }

    static func string(_ attribute: String, of element: AXUIElement) -> String? {
        value(attribute, of: element) as? String
    }

    /// Whether a boolean attribute says `true`; an element that does not report it,
    /// or reports anything else, answers `false`.
    static func isTrue(_ attribute: String, of element: AXUIElement) -> Bool {
        value(attribute, of: element) as? Bool ?? false
    }

    /// An attribute whose value is one element. `unsafeDowncast` behind a `CFGetTypeID`
    /// guard, as in the adapter: a conditional cast to a Core Foundation type is
    /// rejected as one that cannot fail, and `as!` is banned.
    static func element(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        guard let value = value(attribute, of: element),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func elements(_ attribute: String, of element: AXUIElement) -> [AXUIElement] {
        value(attribute, of: element) as? [AXUIElement] ?? []
    }

    /// `AXPosition` and `AXSize` together, or `nil` when either is missing.
    static func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = point(kAXPositionAttribute, of: element),
              let size = size(kAXSizeAttribute, of: element)
        else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// The process an element belongs to — the answer to "is this container the
    /// frontmost application's, or another process's?".
    static func processIdentifier(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }
        return pid
    }

    /// `role/subrole`, with `-` for either one the element does not report.
    static func roleAndSubrole(of element: AXUIElement) -> String {
        let role = string(kAXRoleAttribute, of: element) ?? "-"
        let subrole = string(kAXSubroleAttribute, of: element) ?? "-"
        return "\(role)/\(subrole)"
    }

    private static func point(_ attribute: String, of element: AXUIElement) -> CGPoint? {
        var point = CGPoint.zero
        guard let boxed = axValue(attribute, of: element, type: .cgPoint),
              AXValueGetValue(boxed, .cgPoint, &point)
        else {
            return nil
        }
        return point
    }

    private static func size(_ attribute: String, of element: AXUIElement) -> CGSize? {
        var size = CGSize.zero
        guard let boxed = axValue(attribute, of: element, type: .cgSize),
              AXValueGetValue(boxed, .cgSize, &size)
        else {
            return nil
        }
        return size
    }

    private static func axValue(
        _ attribute: String,
        of element: AXUIElement,
        type: AXValueType,
    ) -> AXValue? {
        guard let value = value(attribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        let boxed = unsafeDowncast(value, to: AXValue.self)
        return AXValueGetType(boxed) == type ? boxed : nil
    }
}
