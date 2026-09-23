import CoreGraphics
import Foundation
import HintjumpCore
@testable import HintjumpUI
import SwiftUI
import Testing

/// The hint overlay's appearance, checked without a window, a screen, or a TCC grant.
///
/// Every scene is rendered off screen (``image(of:)``) and compared pixel by pixel
/// with its committed reference image under `References/`. A change to the tags' layout,
/// colours, type, typed-character dimming, the outlined right-click style, the chip, or
/// the clamping at a screen edge changes pixels and fails here; an intended change is
/// re-recorded with `just record-snapshots`, and the new PNG files are reviewed in the pull
/// request like any other diff. Every tag in a scene is placed by
/// ``HintjumpCore/HintLayout`` from a target frame, the way the session places it, so the
/// scenes exercise the product's own sizes, anchoring, collision fallbacks, and clamping.
@Suite("The hint overlay, rendered off screen, against its reference images")
struct HintOverlayRenderingTests {
    /// A 1 pt gray outline for each of `frames`, given in global coordinates and drawn
    /// relative to `canvas`'s origin the way the overlay positions its tags: the targets the
    /// tags label, which the overlay itself never draws.
    private struct TargetOutlines: View {
        let frames: [CGRect]
        let canvas: CGRect

        var body: some View {
            ZStack(alignment: .topLeading) {
                ForEach(Array(frames.enumerated()), id: \.offset) { _, frame in
                    Rectangle()
                        .strokeBorder(
                            Color(.sRGB, red: 0.55, green: 0.55, blue: 0.58),
                            lineWidth: 1,
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX - canvas.minX, y: frame.midY - canvas.minY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The canvas every scene draws on: small enough to read at a glance in a pull request,
    /// wide enough to put tags over both halves of the backdrop.
    static let canvas = CGRect(x: 0, y: 0, width: 280, height: 120)

    /// Two rows of targets across the light and the dark half: three singles on top,
    /// three pairs below.
    static let rowTargets = [
        CGPoint(x: 40, y: 30), CGPoint(x: 120, y: 30), CGPoint(x: 200, y: 30),
        CGPoint(x: 40, y: 80), CGPoint(x: 120, y: 80), CGPoint(x: 200, y: 80),
    ].map(target(at:))

    /// Every scene the rendering tests compare, one reference image each.
    static let scenes: [OverlayScene] = [
        OverlayScene(
            name: "filled-singles-and-pairs",
            targets: rowTargets,
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(
                    ["a", "s", "d", "fa", "fs", "fd"],
                    on: rowTargets,
                    typed: 0,
                    within: canvas,
                ),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "filled-narrowed-after-typing",
            targets: rowTargets,
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(
                    ["fa", "fs", "fd"],
                    on: Array(rowTargets.suffix(3)),
                    typed: 1,
                    within: canvas,
                ),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "filled-widest-pairs",
            targets: rowTargets,
            overlay: overlay(
                .clickInWindow,
                .filled,
                // Every label is distinct, as in a real overlay, which draws one tag per
                // label.
                hints: hints(["mw", "wm", "ww", "mm"], on: rowTargets, typed: 0, within: canvas),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "outlined-with-chip",
            targets: rowTargets,
            overlay: overlay(
                .rightClickInWindow,
                .outlined,
                hints: hints(
                    ["a", "s", "d", "fa", "fs", "fd"],
                    on: rowTargets,
                    typed: 0,
                    within: canvas,
                ),
                chip: HintLayout.chip(
                    for: CGRect(x: 20, y: 0, width: 240, height: 120),
                    in: canvas,
                ),
            ),
        ),
        clampedAtTheEdges,
        filledCollidingTargets,
    ]

    /// Targets hanging off every edge of the canvas, in a window larger than it, so each
    /// tag is anchored on its whole target and then pushed back inside the canvas: the
    /// left and right edges, the top and bottom edges, and two corners.
    static let clampedAtTheEdges: OverlayScene = {
        let window = CGRect(x: -100, y: -100, width: 480, height: 320)
        let targets = [
            CGPoint(x: -40, y: 50), CGPoint(x: -30, y: -40), CGPoint(x: 250, y: 40),
            CGPoint(x: 250, y: 110), CGPoint(x: 100, y: 100), CGPoint(x: 100, y: -30),
        ].map(target(at:))
        return OverlayScene(
            name: "clamped-at-the-edges",
            targets: targets,
            overlay: overlay(
                .rightClickInWindow,
                .outlined,
                hints: hints(
                    ["a", "fa", "s", "fs", "d", "fd"],
                    on: targets,
                    typed: 0,
                    within: window,
                ),
                chip: HintLayout.chip(
                    for: CGRect(x: 200, y: -40, width: 200, height: 100),
                    in: canvas,
                ),
            ),
        )
    }()

    /// Targets whose bottom-center spots collide, so later-ranked tags move: on the light
    /// half, an overlapping neighbor's tag goes to its top center, and five tags on one
    /// wide target take bottom center, top center, bottom leading, and bottom trailing,
    /// and the fifth, colliding everywhere, stays at bottom center under the
    /// better-ranked `D` drawn on top of it; on the dark half, compact 18 pt list rows,
    /// where the middle row's tag goes to bottom leading.
    static let filledCollidingTargets: OverlayScene = {
        let wide = CGRect(x: 25, y: 75, width: 90, height: 20)
        let targets = [
            CGRect(x: 20, y: 20, width: 60, height: 20),
            CGRect(x: 30, y: 20, width: 60, height: 20),
            wide, wide, wide, wide, wide,
            CGRect(x: 150, y: 25, width: 120, height: 18),
            CGRect(x: 150, y: 43, width: 120, height: 18),
            CGRect(x: 150, y: 61, width: 120, height: 18),
        ]
        let labels = ["a", "s", "d", "fa", "fs", "fd", "fg", "j", "k", "l"]
        return OverlayScene(
            name: "filled-colliding-targets",
            targets: targets,
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(labels, on: targets, typed: 0, within: canvas),
                chip: nil,
            ),
        )
    }()

    /// Pixels per point: a Retina display's, fixed so the image does not depend on the
    /// machine that renders it.
    static let scale: CGFloat = 2

    /// A 60 × 20 target whose top-left corner is `origin`.
    static func target(at origin: CGPoint) -> CGRect {
        CGRect(origin: origin, size: CGSize(width: 60, height: 20))
    }

    /// Tags for `labels`, in rank order, on `targets` in a window at `root`, placed the way
    /// the session places them, with `typed` characters already typed on every tag.
    static func hints(
        _ labels: [String],
        on targets: [CGRect],
        typed: Int,
        within root: CGRect,
    ) -> [PlacedHint] {
        let tags = zip(labels, targets).map { LabeledFrame(label: $0, frame: $1) }
        return HintLayout.placedHints(tags, within: root, in: canvas).map { placed in
            PlacedHint(
                label: placed.label,
                typedCount: typed,
                center: placed.center,
                size: placed.size,
            )
        }
    }

    static func overlay(
        _ entryPoint: EntryPoint,
        _ style: HintStyle,
        hints: [PlacedHint],
        chip: PlacedChip?,
    ) -> HintOverlayState {
        HintOverlayState(
            entryPoint: entryPoint,
            style: style,
            canvas: canvas,
            hints: hints,
            chip: chip,
        )
    }

    /// `scene` rendered off screen at ``scale``, or `nil` when the renderer produced nothing.
    ///
    /// `ImageRenderer` needs no window, no display, and no TCC grant, so this runs under
    /// `just test` and in CI. The overlay is drawn over a backdrop split into a light and a
    /// dark half: the overlay itself is transparent, and its tags sit over other apps' light
    /// and dark content alike, so an image of the tags alone would hide how the outline
    /// separates a tag from a light background and the fill from a dark one. Each target's
    /// frame is outlined in gray under the tags, so the image shows where a tag sits on its
    /// target.
    @MainActor
    static func image(of scene: OverlayScene) -> CGImage? {
        let size = scene.overlay.canvas.size
        let content = ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95)
                Color(.sRGB, red: 0.17, green: 0.17, blue: 0.18)
            }
            TargetOutlines(frames: scene.targets, canvas: scene.overlay.canvas)
            HintOverlayCanvas(overlay: scene.overlay)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    @Test(arguments: Self.scenes)
    @MainActor
    func `renders exactly as its reference image`(scene: OverlayScene) throws {
        let rendered = try #require(
            Self.image(of: scene),
            "ImageRenderer produced no image for \(scene.name)",
        )
        try ReferenceImages.check(rendered, named: scene.name)
    }

    /// The widest pair the default hint characters make, uppercased, fits inside a pair
    /// tag with room to spare, so no label is clipped.
    @Test(arguments: ["MW", "WM", "WW", "MM"])
    @MainActor
    func `the widest pair fits the pair width`(label: String) throws {
        let renderer = ImageRenderer(content: Text(label).font(Palette.labelFont).fixedSize())
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        #expect(CGFloat(image.width) <= HintLayout.pairTagWidth - 2 * Palette.outlineWidth)
    }

    /// The comparison is not vacuous: two different states render to different pixels.
    @Test
    @MainActor
    func `different overlay states render to different pixels`() throws {
        let images = try Self.scenes.map { scene in
            try RGBAPixels(#require(Self.image(of: scene)))
        }

        for (index, image) in images.enumerated() {
            for other in images[(index + 1)...] {
                let difference = PixelDifference(actual: image, reference: other, tolerance: 0)
                #expect(difference.differingPixels > 0)
            }
        }
    }

    /// The tolerance is not so loose that it hides a small layout change.
    @Test
    @MainActor
    func `a tag moved by one point is caught`() throws {
        let scene = try #require(Self.scenes.first)
        var moved = scene.overlay
        let first = try #require(moved.hints.first)
        moved.hints[0] = PlacedHint(
            label: first.label,
            typedCount: first.typedCount,
            center: CGPoint(x: first.center.x + 1, y: first.center.y),
            size: first.size,
        )
        let original = try RGBAPixels(#require(Self.image(of: scene)))
        let shifted = try RGBAPixels(#require(Self.image(of: OverlayScene(
            name: scene.name,
            targets: scene.targets,
            overlay: moved,
        ))))

        let difference = PixelDifference(
            actual: shifted,
            reference: original,
            tolerance: ReferenceImages.tolerance,
        )

        #expect(difference.differingPixels > 0)
    }
}
