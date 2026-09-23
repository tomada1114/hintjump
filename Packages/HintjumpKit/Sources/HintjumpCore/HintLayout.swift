import CoreGraphics

/// Where hint tags and the right-click chip go on the overlay's canvas, and how big they
/// are.
///
/// Every number here is **provisional**: a stand-in until #21 publishes
/// `docs/design/design-system.md`, whose values replace these constants without changing
/// the shape of anything that reads them. The constants are public so the view sizes its
/// tags from the same numbers the placement used. Tag size is fixed, with no setting
/// (`docs/decisions.md` › "Four small questions closed for the first release").
public enum HintLayout {
    /// A tag's height, whatever its label.
    public static let tagHeight: CGFloat = 18
    /// A single-character tag's width: square.
    public static let singleTagWidth: CGFloat = 18
    /// A two-character tag's width.
    public static let pairTagWidth: CGFloat = 26
    /// What the right-click chip reads.
    public static let chipText = "Right click"
    /// The right-click chip's height.
    public static let chipHeight: CGFloat = 20
    /// The right-click chip's width: fixed, like a tag's, so Core can place and clamp it
    /// without measuring text — room for ``chipText`` at the overlay's chip font with
    /// 8 pt of padding either side.
    public static let chipWidth: CGFloat = 76
    /// How far below the window's top edge the chip's top sits.
    public static let chipTopInset: CGFloat = 8

    /// Half of a length: a box's center is half its size in from its edge.
    private static let half: CGFloat = 0.5

    /// The fixed size of the tag that shows `label`: square for one character, wider for
    /// two.
    public static func tagSize(forLabel label: String) -> CGSize {
        CGSize(width: label.count <= 1 ? singleTagWidth : pairTagWidth, height: tagHeight)
    }

    /// The center of a tag of `size` for a target at `targetFrame`, relative to
    /// `canvas`'s origin.
    ///
    /// The tag straddles the target's left edge, vertically centered on it (`docs/decisions.md`
    /// › "Design: signpost hints, one accent, system controls everywhere else"); a tag
    /// that would then hang off the canvas is pushed back inside it, which is what keeps
    /// a target flush with the screen's left edge labeled.
    public static func tagCenter(
        for targetFrame: CGRect,
        size: CGSize,
        in canvas: CGRect,
    ) -> CGPoint {
        let anchor = CGPoint(x: targetFrame.minX, y: targetFrame.midY)
        return clamped(relative(anchor, to: canvas), size: size, in: canvas.size)
    }

    /// A tag for `label` on a target at `targetFrame`, with nothing typed yet.
    public static func placedHint(
        label: String,
        targetFrame: CGRect,
        in canvas: CGRect,
    ) -> PlacedHint {
        let size = tagSize(forLabel: label)
        return PlacedHint(
            label: label,
            typedCount: 0,
            center: tagCenter(for: targetFrame, size: size, in: canvas),
            size: size,
        )
    }

    /// The right-click chip for a window at `rootFrame`: centered on it horizontally,
    /// its top ``chipTopInset`` below the window's top edge, clamped inside `canvas` the
    /// same way a tag is.
    public static func chip(for rootFrame: CGRect, in canvas: CGRect) -> PlacedChip {
        let size = CGSize(width: chipWidth, height: chipHeight)
        let anchor = CGPoint(
            x: rootFrame.midX,
            y: rootFrame.minY + chipTopInset + chipHeight * half,
        )
        return PlacedChip(
            text: chipText,
            center: clamped(relative(anchor, to: canvas), size: size, in: canvas.size),
            size: size,
        )
    }

    private static func relative(_ point: CGPoint, to canvas: CGRect) -> CGPoint {
        CGPoint(x: point.x - canvas.minX, y: point.y - canvas.minY)
    }

    /// `center` moved the least distance that keeps a box of `size` around it inside a
    /// canvas of `canvasSize`. A box larger than the canvas is pinned to its top-left.
    private static func clamped(_ center: CGPoint, size: CGSize, in canvasSize: CGSize) -> CGPoint {
        let halfWidth = size.width * half
        let halfHeight = size.height * half
        return CGPoint(
            x: max(halfWidth, min(canvasSize.width - halfWidth, center.x)),
            y: max(halfHeight, min(canvasSize.height - halfHeight, center.y)),
        )
    }
}
