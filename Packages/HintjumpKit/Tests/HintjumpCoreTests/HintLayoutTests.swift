import CoreGraphics
import HintjumpCore
import Testing

/// Where a hint tag and the right-click chip sit on the overlay's canvas.
@Suite("HintLayout")
struct HintLayoutTests {
    /// A canvas at the global origin, so canvas-relative and global points coincide.
    static let canvas = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    /// A read's root far larger than the canvas, so a target is anchored on its whole
    /// frame and only the canvas clamps it.
    static let everywhere = CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)

    @Test
    func `a single-character tag is square and a two-character tag is wider`() {
        #expect(HintLayout.tagSize(forLabel: "a") == CGSize(width: 18, height: 18))
        #expect(HintLayout.tagSize(forLabel: "ia") == CGSize(width: 26, height: 18))
    }

    @Test
    func `a tag is centered on the target's bottom edge`() {
        let target = CGRect(x: 100, y: 200, width: 50, height: 30)
        let size = HintLayout.tagSize(forLabel: "a")
        let center = HintLayout.tagCenter(
            for: target,
            within: Self.canvas,
            size: size,
            in: Self.canvas,
        )
        #expect(center == CGPoint(x: 125, y: 230))
    }

    @Test
    func `a tag's center is relative to the canvas origin`() {
        let offsetCanvas = CGRect(x: 100, y: 50, width: 1_000, height: 800)
        let target = CGRect(x: 300, y: 250, width: 40, height: 20)
        let size = HintLayout.tagSize(forLabel: "a")
        let center = HintLayout.tagCenter(
            for: target,
            within: offsetCanvas,
            size: size,
            in: offsetCanvas,
        )
        #expect(center == CGPoint(x: 220, y: 220))
    }

    @Test(arguments: [
        // Hanging off the root's right edge: only its left 50 pt show.
        (CGRect(x: 450, y: 100, width: 100, height: 20), CGPoint(x: 475, y: 120)),
        // Scrolled half below the root's bottom edge: only its top 10 pt show.
        (CGRect(x: 100, y: 390, width: 40, height: 30), CGPoint(x: 120, y: 400)),
        // Hanging off the root's top-left corner.
        (CGRect(x: -40, y: -10, width: 80, height: 30), CGPoint(x: 20, y: 20)),
    ])
    func `a target hanging off the root is anchored on its visible part`(
        target: CGRect,
        expected: CGPoint,
    ) {
        let root = CGRect(x: 0, y: 0, width: 500, height: 400)
        let size = HintLayout.tagSize(forLabel: "a")
        #expect(HintLayout
            .tagCenter(for: target, within: root, size: size, in: Self.canvas) == expected)
    }

    @Test(arguments: [
        // Wholly outside the root.
        (
            CGRect(x: 600, y: 100, width: 40, height: 20),
            CGRect(x: 0, y: 0, width: 500, height: 400),
        ),
        // Touching the root only along its right edge: no area in common.
        (
            CGRect(x: 500, y: 100, width: 40, height: 20),
            CGRect(x: 0, y: 0, width: 500, height: 400),
        ),
        // A read that reported no root frame.
        (CGRect(x: 600, y: 100, width: 40, height: 20), CGRect.zero),
    ])
    func `a target with no visible part is anchored on its whole frame`(
        target: CGRect,
        root: CGRect,
    ) {
        let size = HintLayout.tagSize(forLabel: "a")
        let center = HintLayout.tagCenter(for: target, within: root, size: size, in: Self.canvas)
        #expect(center == CGPoint(x: target.midX, y: target.maxY))
    }

    @Test(arguments: [
        // Left edge: the target's middle is on the canvas's left edge.
        (CGRect(x: -10, y: 100, width: 20, height: 20), "a", CGPoint(x: 9, y: 120)),
        (CGRect(x: -10, y: 100, width: 20, height: 20), "ia", CGPoint(x: 13, y: 120)),
        // Right edge: the target's middle is on the canvas's right edge.
        (CGRect(x: 990, y: 100, width: 20, height: 20), "a", CGPoint(x: 991, y: 120)),
        (CGRect(x: 990, y: 100, width: 20, height: 20), "ia", CGPoint(x: 987, y: 120)),
        // Top edge: the target's bottom is on the canvas's top edge.
        (CGRect(x: 100, y: -30, width: 40, height: 30), "a", CGPoint(x: 120, y: 9)),
        // Bottom edge: the target's bottom is on the canvas's bottom edge, so the tag is
        // pushed up onto the target.
        (CGRect(x: 100, y: 780, width: 40, height: 20), "a", CGPoint(x: 120, y: 791)),
        (CGRect(x: 100, y: 780, width: 40, height: 20), "ia", CGPoint(x: 120, y: 791)),
        // A corner: clamped on both axes at once.
        (CGRect(x: -20, y: -20, width: 20, height: 20), "a", CGPoint(x: 9, y: 9)),
    ])
    func `a tag that would leave the canvas is clamped inside it`(
        target: CGRect,
        label: String,
        expected: CGPoint,
    ) {
        let size = HintLayout.tagSize(forLabel: label)
        let center = HintLayout.tagCenter(
            for: target,
            within: Self.everywhere,
            size: size,
            in: Self.canvas,
        )
        #expect(center == expected)
    }

    @Test
    func `the right-click chip is centered on the window, its top 8 pt below the window's`() {
        let root = CGRect(x: 100, y: 100, width: 600, height: 400)
        let chip = HintLayout.chip(for: root, in: Self.canvas)
        #expect(chip.text == "Right click")
        #expect(chip.size == CGSize(width: HintLayout.chipWidth, height: 20))
        #expect(chip.center == CGPoint(x: 400, y: 118))
    }

    @Test
    func `the chip is clamped inside the canvas like a tag`() {
        let root = CGRect(x: -500, y: 790, width: 520, height: 400)
        let chip = HintLayout.chip(for: root, in: Self.canvas)
        #expect(chip.center == CGPoint(x: HintLayout.chipWidth / 2, y: 790))
    }

    @Test
    func `placed hints carry their labels and sizes, in rank order, with nothing typed`() {
        let tags = [
            LabeledFrame(label: "ia", frame: CGRect(x: 100, y: 200, width: 50, height: 30)),
            LabeledFrame(label: "a", frame: CGRect(x: 300, y: 200, width: 50, height: 30)),
        ]
        let hints = HintLayout.placedHints(tags, within: Self.canvas, in: Self.canvas)
        #expect(hints == [
            PlacedHint(
                label: "ia",
                typedCount: 0,
                center: CGPoint(x: 125, y: 230),
                size: CGSize(width: 26, height: 18),
            ),
            PlacedHint(
                label: "a",
                typedCount: 0,
                center: CGPoint(x: 325, y: 230),
                size: CGSize(width: 18, height: 18),
            ),
        ])
    }

    @Test
    func `the best-ranked tag is drawn last, on top of the others`() {
        let tags = ["a", "s", "d"].enumerated().map { index, label in
            LabeledFrame(
                label: label,
                frame: CGRect(x: 100 * CGFloat(index), y: 100, width: 40, height: 20),
            )
        }
        let overlay = HintOverlayState(
            entryPoint: .clickInWindow,
            style: .filled,
            canvas: Self.canvas,
            hints: HintLayout.placedHints(tags, within: Self.canvas, in: Self.canvas),
            chip: nil,
        )
        #expect(overlay.hints.map(\.label) == ["a", "s", "d"])
        #expect(overlay.hintsInDrawingOrder.map(\.label) == ["d", "s", "a"])
    }
}
