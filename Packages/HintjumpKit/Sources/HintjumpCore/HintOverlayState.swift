import CoreGraphics

/// How the tags look: the frontmost-window left click fills them, the right click
/// outlines them (`docs/decisions.md` › "Design: signpost hints, one accent, system
/// controls everywhere else").
public enum HintStyle: Equatable, Sendable {
    /// Near-black tags, singles filled with the accent.
    case filled
    /// The same tags outlined, which is how the right-click entry point reads.
    case outlined
}

/// One tag as the overlay draws it: every number already decided in Core, so the view
/// only positions and paints.
public struct PlacedHint: Equatable, Sendable {
    /// The label, as the user types it.
    public let label: String
    /// How many leading characters of ``label`` are already typed — the view dims them.
    public let typedCount: Int
    /// Whether the label is a single character, which the accent marks.
    public let isSingle: Bool
    /// The tag's center, relative to the canvas's top-left corner.
    public let center: CGPoint
    /// The tag's fixed size (``HintLayout``).
    public let size: CGSize

    public init(label: String, typedCount: Int, isSingle: Bool, center: CGPoint, size: CGSize) {
        self.label = label
        self.typedCount = typedCount
        self.isSingle = isSingle
        self.center = center
        self.size = size
    }
}

/// The "Right click" chip the right-click entry point shows above its tags.
public struct PlacedChip: Equatable, Sendable {
    /// What the chip reads.
    public let text: String
    /// The chip's center, relative to the canvas's top-left corner.
    public let center: CGPoint
    /// The chip's fixed size (``HintLayout``).
    public let size: CGSize

    public init(text: String, center: CGPoint, size: CGSize) {
        self.text = text
        self.center = center
        self.size = size
    }
}

/// Everything the overlay renders while hints are shown, and nothing else — the value
/// ``HintSession/overlay`` publishes and the view draws.
public struct HintOverlayState: Equatable, Sendable {
    /// The trigger that showed these hints.
    public let entryPoint: EntryPoint
    /// Filled or outlined tags.
    public let style: HintStyle
    /// The overlay's frame in global, top-left-origin coordinates: the screen that holds
    /// the target window. Every ``PlacedHint/center`` is relative to its origin.
    public let canvas: CGRect
    /// The tags still reachable, in rank order: all of them until a first character
    /// narrows, then only the labels it starts.
    public var hints: [PlacedHint]
    /// The right-click chip, for ``EntryPoint/rightClickInWindow`` only.
    public let chip: PlacedChip?

    public init(
        entryPoint: EntryPoint,
        style: HintStyle,
        canvas: CGRect,
        hints: [PlacedHint],
        chip: PlacedChip?,
    ) {
        self.entryPoint = entryPoint
        self.style = style
        self.canvas = canvas
        self.hints = hints
        self.chip = chip
    }
}
