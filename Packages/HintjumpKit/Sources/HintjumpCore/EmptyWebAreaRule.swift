/// "Has an `AXWebArea` with no children" — the trigger for waking an Electron or
/// Chromium tree once per process (`docs/decisions.md` › "Chromium-based apps are in
/// the first release's scope; no wake by default").
///
/// A narrow rule over ``TreeSnapshot``, kept apart from ``ManualAccessibilityWaker`` so
/// it can be tested against a snapshot value alone, with no port and no fake.
public enum EmptyWebAreaRule {
    /// `true` when `snapshot` has an element whose ``ElementSnapshot/role`` is
    /// `"AXWebArea"` and no other element's ``ElementSnapshot/parentIndex`` points at
    /// its index — an Electron or Chromium tree that never built its DOM-backed
    /// children, the one case the fallback in `docs/decisions.md` exists for.
    public static func matches(_ snapshot: TreeSnapshot) -> Bool {
        let parentIndices = Set(snapshot.elements.compactMap(\.parentIndex))
        return snapshot.elements.indices.contains { index in
            snapshot.elements[index].role == "AXWebArea" && !parentIndices.contains(index)
        }
    }
}
