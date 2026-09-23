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
    /// The least room kept between two tags: closer than this, the later-ranked one moves.
    public static let tagGap: CGFloat = 1

    /// Half of a length: a box's center is half its size in from its edge.
    private static let half: CGFloat = 0.5

    /// The fixed size of the tag that shows `label`: square for one character, wider for
    /// two.
    public static func tagSize(forLabel label: String) -> CGSize {
        CGSize(width: label.count <= 1 ? singleTagWidth : pairTagWidth, height: tagHeight)
    }

    /// The center of a tag of `size` for a target at `targetFrame`, relative to
    /// `canvas`'s origin, before any other tag is considered.
    ///
    /// The tag is centered horizontally on the target and straddles its bottom edge
    /// (`docs/decisions.md` › "Design: signpost hints, one accent, system controls
    /// everywhere else", amended by #114), so it covers neither the leading icon nor the
    /// first letters of the title that tell the user which element it labels. The
    /// target is measured by its part inside `root`, the read's root — the rectangle
    /// ``ClickPointRule`` clicks the center of — so a row scrolled half out of view is
    /// labeled where it shows; a target with no area inside `root` falls back to its
    /// whole frame. A tag that would then hang off the canvas is pushed back inside it,
    /// which is what lifts the tag of a target at the screen's bottom edge onto it.
    public static func tagCenter(
        for targetFrame: CGRect,
        within root: CGRect,
        size: CGSize,
        in canvas: CGRect,
    ) -> CGPoint {
        let visible = visiblePart(of: targetFrame, within: root)
        return center(at: CGPoint(x: visible.midX, y: visible.maxY), size: size, in: canvas)
    }

    /// The tags for `tags`, given in rank order, with nothing typed yet — returned in the
    /// same order.
    ///
    /// Each tag goes to its ``tagCenter(for:within:size:in:)`` unless that box, with a
    /// ``tagGap`` around it, overlaps a tag already placed; better-ranked tags are placed
    /// first, so they keep their spots. A colliding tag takes the first of its
    /// ``fallbackCenters(for:size:in:)`` that overlaps nothing placed, and keeps its
    /// bottom-center spot when every one does. The check is pairwise, which is ample for
    /// the at most 276 labels the hint characters make. The right-click chip is not a
    /// tag and takes no part.
    public static func placedHints(
        _ tags: [LabeledFrame],
        within root: CGRect,
        in canvas: CGRect,
    ) -> [PlacedHint] {
        var taken: [CGRect] = []
        return tags.map { tag in
            let size = tagSize(forLabel: tag.label)
            let visible = visiblePart(of: tag.frame, within: root)
            let candidates = [tagCenter(for: tag.frame, within: root, size: size, in: canvas)]
                + fallbackCenters(for: visible, size: size, in: canvas)
            let chosen = candidates.first { candidate in
                let padded = box(around: candidate, size: size).insetBy(dx: -tagGap, dy: -tagGap)
                return !taken.contains { overlaps(padded, $0) }
            } ?? candidates[0]
            taken.append(box(around: chosen, size: size))
            return PlacedHint(label: tag.label, typedCount: 0, center: chosen, size: size)
        }
    }

    /// Where a tag whose bottom-center spot is taken tries next, in order, each clamped
    /// inside the canvas like the bottom center: the top center, `(visible.midX,
    /// visible.minY)`; then bottom leading, the tag's left edge on the visible part's left
    /// edge (`visible.minX`) with its center on the bottom edge (`visible.maxY`); then
    /// bottom trailing, its right edge on the visible part's right edge (`visible.maxX`),
    /// also on the bottom edge. Leading and trailing are the left and right edges on
    /// screen, not by writing direction: labels are ASCII and the overlay is laid out in
    /// screen coordinates.
    private static func fallbackCenters(
        for visible: CGRect,
        size: CGSize,
        in canvas: CGRect,
    ) -> [CGPoint] {
        let halfWidth = size.width * half
        return [
            CGPoint(x: visible.midX, y: visible.minY),
            CGPoint(x: visible.minX + halfWidth, y: visible.maxY),
            CGPoint(x: visible.maxX - halfWidth, y: visible.maxY),
        ].map { center(at: $0, size: size, in: canvas) }
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
            center: center(at: anchor, size: size, in: canvas),
            size: size,
        )
    }

    /// `frame ∩ root`, or `frame` itself when the two share no area — the same visible
    /// part ``ClickPointRule`` clicks, with a fallback so a tag is never lost.
    private static func visiblePart(of frame: CGRect, within root: CGRect) -> CGRect {
        let visible = frame.intersection(root)
        return visible.isEmpty ? frame : visible
    }

    /// The canvas-relative center of a box of `size` anchored at the global point
    /// `anchor`, clamped inside `canvas`.
    private static func center(at anchor: CGPoint, size: CGSize, in canvas: CGRect) -> CGPoint {
        clamped(relative(anchor, to: canvas), size: size, in: canvas.size)
    }

    /// Whether `first` and `second` share an area. Boxes that only touch along an edge
    /// do not, so two tags exactly ``tagGap`` apart are not a collision.
    private static func overlaps(_ first: CGRect, _ second: CGRect) -> Bool {
        first.minX < second.maxX && second.minX < first.maxX
            && first.minY < second.maxY && second.minY < first.maxY
    }

    /// The box of `size` centered on `center`.
    private static func box(around center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width * half,
            y: center.y - size.height * half,
            width: size.width,
            height: size.height,
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
