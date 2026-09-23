import CoreGraphics
import HintjumpCore
import Testing

extension HintLayoutTests {
    /// Where a tag goes when its bottom-center spot is already taken by a better-ranked one.
    @Suite("collisions")
    struct Collisions {
        /// A target wide enough that its leading and trailing spots clear its bottom center.
        static let wide = CGRect(x: 100, y: 100, width: 80, height: 20)

        /// The centers `labels` get when every one labels a target at `frame`.
        static func centers(of labels: [String], on frame: CGRect) -> [CGPoint] {
            let tags = labels.map { LabeledFrame(label: $0, frame: frame) }
            return HintLayout.placedHints(
                tags,
                within: HintLayoutTests.canvas,
                in: HintLayoutTests.canvas,
            )
            .map(\.center)
        }

        @Test
        func `a colliding tag tries top center, then bottom leading, then bottom trailing`() {
            #expect(Self.centers(of: ["a", "s", "d", "f"], on: Self.wide) == [
                // Bottom center: (midX, maxY).
                CGPoint(x: 140, y: 120),
                // Top center: (midX, minY).
                CGPoint(x: 140, y: 100),
                // Bottom leading: the tag's left edge on the target's left edge.
                CGPoint(x: 109, y: 120),
                // Bottom trailing: the tag's right edge on the target's right edge.
                CGPoint(x: 171, y: 120),
            ])
        }

        @Test
        func `a tag that collides everywhere keeps its bottom-center spot`() {
            let centers = Self.centers(of: ["a", "s", "d", "f", "g"], on: Self.wide)
            #expect(centers.last == CGPoint(x: 140, y: 120))
        }

        @Test
        func `a narrow target's tags fall back in the same order`() {
            // 18 pt wide, the size of a single tag: leading and trailing coincide with the
            // bottom center, so the third tag has nowhere else to go.
            let narrow = CGRect(x: 100, y: 100, width: 18, height: 20)
            #expect(Self.centers(of: ["a", "s", "d"], on: narrow) == [
                CGPoint(x: 109, y: 120),
                CGPoint(x: 109, y: 100),
                CGPoint(x: 109, y: 120),
            ])
        }

        /// A 1 pt gap is kept between tags: a neighbor whose tag would sit a full point away
        /// keeps its bottom-center spot, and one any closer moves.
        @Test(arguments: [
            // The second tag's left edge 1 pt right of the first's right edge.
            (CGFloat(19), CGPoint(x: 139, y: 120)),
            // Half a point closer: within the gap.
            (CGFloat(18.5), CGPoint(x: 138.5, y: 100)),
            // Touching.
            (CGFloat(18), CGPoint(x: 138, y: 100)),
        ])
        func `tags closer than 1 pt apart collide`(offset: CGFloat, expected: CGPoint) {
            let first = CGRect(x: 100, y: 100, width: 40, height: 20)
            let tags = [
                LabeledFrame(label: "a", frame: first),
                LabeledFrame(label: "s", frame: first.offsetBy(dx: offset, dy: 0)),
            ]
            let hints = HintLayout.placedHints(
                tags,
                within: HintLayoutTests.canvas,
                in: HintLayoutTests.canvas,
            )
            #expect(hints.map(\.center) == [CGPoint(x: 120, y: 120), expected])
        }

        @Test
        func `a fallback is judged where the clamp puts it`() {
            // Flush with the canvas's left edge: the bottom-leading spot would hang off the
            // canvas, and clamped back inside it overlaps the first tag, so the third tag
            // goes to the bottom-trailing spot.
            // The root reaches past the canvas, so the whole target is visible.
            let atLeftEdge = CGRect(x: -20, y: 100, width: 80, height: 20)
            let tags = ["a", "s", "d"].map { LabeledFrame(label: $0, frame: atLeftEdge) }
            let hints = HintLayout.placedHints(
                tags,
                within: HintLayoutTests.everywhere,
                in: HintLayoutTests.canvas,
            )
            #expect(hints.map(\.center) == [
                CGPoint(x: 20, y: 120),
                CGPoint(x: 20, y: 100),
                CGPoint(x: 51, y: 120),
            ])
        }

        @Test
        func `a tag is checked against every tag placed before it, not only the last`() {
            // The second tag is placed far away, so only the first one is in the third's
            // bottom-center spot.
            let tags = [
                LabeledFrame(label: "a", frame: Self.wide),
                LabeledFrame(label: "s", frame: Self.wide.offsetBy(dx: 400, dy: 0)),
                LabeledFrame(label: "d", frame: Self.wide),
            ]
            let hints = HintLayout.placedHints(
                tags,
                within: HintLayoutTests.canvas,
                in: HintLayoutTests.canvas,
            )
            #expect(hints.map(\.center) == [
                CGPoint(x: 140, y: 120),
                CGPoint(x: 540, y: 120),
                CGPoint(x: 140, y: 100),
            ])
        }
    }
}
