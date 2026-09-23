/// "Has a top-level `AXWebArea` with no children" — the trigger for waking an Electron
/// or Chromium tree once per process (`docs/decisions.md` › "Chromium-based apps are in
/// the first release's scope; no wake by default").
///
/// A narrow rule over ``TreeSnapshot``, kept apart from ``ManualAccessibilityWaker`` so
/// it can be tested against a snapshot value alone, with no port and no fake.
public enum EmptyWebAreaRule {
    /// `true` when `snapshot` has an element whose ``ElementSnapshot/role`` is
    /// `"AXWebArea"`, no other element's ``ElementSnapshot/parentIndex`` points at its
    /// index, and no `AXWebArea` is among its ancestors — an Electron or Chromium tree
    /// that never built its DOM-backed children, the one case the fallback in
    /// `docs/decisions.md` exists for.
    ///
    /// The ancestor condition is what keeps an iframe out: each iframe is its own nested
    /// `AXWebArea`, and a `batchedPruned` read records an off-screen or sliver-sized one
    /// without its children, so an ad frame below the fold would otherwise wake a
    /// browser and cost it a second read for nothing.
    public static func matches(_ snapshot: TreeSnapshot) -> Bool {
        let elements = snapshot.elements
        let parentIndices = Set(elements.compactMap(\.parentIndex))
        return elements.indices.contains { index in
            isWebArea(elements[index])
                && !parentIndices.contains(index)
                && !TargetRanker.ancestors(ofElementAt: index, in: elements)
                .contains(where: isWebArea)
        }
    }

    private static func isWebArea(_ element: ElementSnapshot) -> Bool {
        element.role == "AXWebArea"
    }
}
