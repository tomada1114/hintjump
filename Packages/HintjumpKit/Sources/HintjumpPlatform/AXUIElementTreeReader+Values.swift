import ApplicationServices

/// Reading raw Accessibility values, and turning them into Swift ones.
///
/// Nothing here throws: a single element's attribute that the application will not
/// answer for is an absence, not a failure, so every function returns `nil` or an empty
/// collection. Only the root read in `AXUIElementTreeReader.swift` can fail a whole read.
extension AXUIElementTreeReader {
    /// Every attribute named in `names` of one element in a single Accessibility call.
    ///
    /// The options are empty rather than `.stopOnError`, so an attribute this element
    /// does not support does not abandon the others: its slot comes back as an `AXValue`
    /// carrying an `AXError`, which ``isFailure(_:)`` drops. The result is keyed by name
    /// instead of read by position, so the two read paths cannot drift out of order.
    static func batchedValues(of element: AXUIElement, names: [String]) -> [String: AnyObject] {
        var raw: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element,
            names as CFArray,
            AXCopyMultipleAttributeOptions(),
            &raw,
        )
        guard error == .success, let values = raw as? [AnyObject] else {
            return [:]
        }

        var result: [String: AnyObject] = [:]
        for (name, value) in zip(names, values) where !isFailure(value) {
            result[name] = value
        }
        return result
    }

    /// The same attributes, one Accessibility call each.
    static func individualValues(of element: AXUIElement, names: [String]) -> [String: AnyObject] {
        var result: [String: AnyObject] = [:]
        for name in names {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
                  let value
            else {
                continue
            }
            result[name] = value
        }
        return result
    }

    /// The action names the element supports, or none when it supports none.
    static func actionNames(of element: AXUIElement) -> [String] {
        var raw: CFArray?
        guard AXUIElementCopyActionNames(element, &raw) == .success,
              let names = raw as? [String]
        else {
            return []
        }
        return names
    }

    // The optional is the point here, not an oversight — see the doc comment below.
    // swiftlint:disable discouraged_optional_collection
    /// The elements held by `attribute`, or `nil` when the element does not publish it.
    ///
    /// `nil` and `[]` mean different things here, which is why the optional stays: the
    /// first is "this element has no such attribute, ask something else", the second is
    /// "this element says nothing is visible", which a pruning walk must honour rather
    /// than fall back from.
    static func elements(_ attribute: String, of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else {
            return nil
        }
        return value as? [AXUIElement]
    }

    // swiftlint:enable discouraged_optional_collection

    /// The element's bounds, or `nil` when it reports no position or no size.
    static func frame(from values: [String: AnyObject]) -> CGRect? {
        guard let origin = point(from: values[kAXPositionAttribute as String]),
              let size = size(from: values[kAXSizeAttribute as String])
        else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// Whether a batched read put an error in this slot instead of a value.
    static func isFailure(_ value: AnyObject) -> Bool {
        guard let boxed = axValue(value) else {
            return false
        }
        return AXValueGetType(boxed) == .axError
    }

    private static func point(from value: AnyObject?) -> CGPoint? {
        guard let boxed = axValue(value), AXValueGetType(boxed) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(boxed, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private static func size(from value: AnyObject?) -> CGSize? {
        guard let boxed = axValue(value), AXValueGetType(boxed) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(boxed, .cgSize, &size) else {
            return nil
        }
        return size
    }

    /// The `AXValue` box an attribute came back in, when it is one.
    ///
    /// The type id is checked before the cast: a conditional cast to a Core Foundation
    /// type is one Swift rejects as unfailable, and an attribute can answer with any CF
    /// type at all.
    private static func axValue(_ value: AnyObject?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
    }
}
