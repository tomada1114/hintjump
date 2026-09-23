/// Why shown hints were closed without a click — the `reason=` a `cancel` log line names.
enum HintCancelReason: String {
    /// Esc.
    case escape
    /// The overlay lost key status without being asked: a click elsewhere, an app switch.
    case resigned
    /// A trigger was pressed while the hints were up.
    case retrigger
}

/// What ``HintSession`` holds while hints are on screen: which labels go to which
/// targets, where every tag was placed, and how far typing has narrowed them.
struct ActiveHints {
    /// The trigger that showed them.
    let entryPoint: EntryPoint
    /// Which `show` these hints belong to, so a handler from a replaced overlay is
    /// recognised as stale.
    let generation: Int
    /// Label to target, for turning a selected label back into a click point.
    let assignment: LabelAssignment<HintTarget>
    /// Every tag as first placed, in rank order, with nothing typed.
    let placed: [PlacedHint]
    /// The key-handling state.
    var matcher: HintMatcher

    /// The tags still reachable, with the typed prefix counted in each — what the
    /// overlay shows after a narrowing or a backspace.
    var visibleHints: [PlacedHint] {
        let candidates = Set(matcher.candidates)
        let typedCount = matcher.typed.count
        return placed.filter { candidates.contains($0.label) }.map { hint in
            PlacedHint(
                label: hint.label,
                typedCount: typedCount,
                center: hint.center,
                size: hint.size,
            )
        }
    }
}
