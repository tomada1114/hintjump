import CoreGraphics
import HintjumpCore
import Testing

/// Where a hint tag and the right-click chip sit on the overlay's canvas.
@Suite("HintLayout")
struct HintLayoutTests {
    /// A canvas at the global origin, so canvas-relative and global points coincide.
    static let canvas = CGRect(x: 0, y: 0, width: 1_000, height: 800)

    @Test
    func `a single-character tag is square and a two-character tag is wider`() {
        #expect(HintLayout.tagSize(forLabel: "a") == CGSize(width: 18, height: 18))
        #expect(HintLayout.tagSize(forLabel: "ia") == CGSize(width: 26, height: 18))
    }

    @Test
    func `a tag straddles the target's left edge, vertically centered`() {
        let target = CGRect(x: 100, y: 200, width: 50, height: 30)
        let size = HintLayout.tagSize(forLabel: "a")
        let center = HintLayout.tagCenter(for: target, size: size, in: Self.canvas)
        #expect(center == CGPoint(x: 100, y: 215))
    }

    @Test
    func `a tag's center is relative to the canvas origin`() {
        let offsetCanvas = CGRect(x: 100, y: 50, width: 1_000, height: 800)
        let target = CGRect(x: 300, y: 250, width: 40, height: 20)
        let size = HintLayout.tagSize(forLabel: "a")
        let center = HintLayout.tagCenter(for: target, size: size, in: offsetCanvas)
        #expect(center == CGPoint(x: 200, y: 210))
    }

    @Test(arguments: [
        // Left edge: the target starts 2 pt in, so half the tag would hang off.
        (CGRect(x: 2, y: 100, width: 40, height: 20), "a", CGPoint(x: 9, y: 110)),
        (CGRect(x: 2, y: 100, width: 40, height: 20), "ia", CGPoint(x: 13, y: 110)),
        // Right edge: the target starts 3 pt before the canvas ends.
        (CGRect(x: 997, y: 100, width: 40, height: 20), "a", CGPoint(x: 991, y: 110)),
        (CGRect(x: 997, y: 100, width: 40, height: 20), "ia", CGPoint(x: 987, y: 110)),
        // Top edge: the target's middle is 3 pt below the canvas top.
        (CGRect(x: 100, y: 0, width: 40, height: 6), "a", CGPoint(x: 100, y: 9)),
        // Bottom edge: the target's middle is 1 pt above the canvas bottom.
        (CGRect(x: 100, y: 796, width: 40, height: 6), "a", CGPoint(x: 100, y: 791)),
        // A corner: clamped on both axes at once.
        (CGRect(x: -20, y: -20, width: 30, height: 30), "a", CGPoint(x: 9, y: 9)),
    ])
    func `a tag that would leave the canvas is clamped inside it`(
        target: CGRect,
        label: String,
        expected: CGPoint,
    ) {
        let size = HintLayout.tagSize(forLabel: label)
        #expect(HintLayout.tagCenter(for: target, size: size, in: Self.canvas) == expected)
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
    func `a placed hint carries its label, its size, and nothing typed yet`() {
        let target = CGRect(x: 100, y: 200, width: 50, height: 30)
        let hint = HintLayout.placedHint(label: "ia", targetFrame: target, in: Self.canvas)
        #expect(hint == PlacedHint(
            label: "ia",
            typedCount: 0,
            isSingle: false,
            center: CGPoint(x: 100, y: 215),
            size: CGSize(width: 26, height: 18),
        ))
        #expect(HintLayout.placedHint(label: "a", targetFrame: target, in: Self.canvas).isSingle)
    }
}
