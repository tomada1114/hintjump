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
/// scenes exercise the product's own sizes and clamping.
@Suite("The hint overlay, rendered off screen, against its reference images")
struct HintOverlayRenderingTests {
    /// The canvas every scene draws on: small enough to read at a glance in a pull request,
    /// wide enough to put tags over both halves of the backdrop.
    static let canvas = CGRect(x: 0, y: 0, width: 280, height: 120)

    /// Two rows across the light and the dark half: three singles on top, three pairs
    /// below.
    static let rowOrigins = [
        CGPoint(x: 40, y: 30), CGPoint(x: 120, y: 30), CGPoint(x: 200, y: 30),
        CGPoint(x: 40, y: 80), CGPoint(x: 120, y: 80), CGPoint(x: 200, y: 80),
    ]

    /// Every scene the rendering tests compare, one reference image each.
    static let scenes: [OverlayScene] = [
        OverlayScene(
            name: "filled-singles-and-pairs",
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(["a", "s", "d", "fa", "fs", "fd"], at: rowOrigins, typed: 0),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "filled-narrowed-after-typing",
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(["fa", "fs", "fd"], at: Array(rowOrigins.suffix(3)), typed: 1),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "filled-widest-pairs",
            overlay: overlay(
                .clickInWindow,
                .filled,
                hints: hints(["mw", "wm", "ww", "mw", "wm", "ww"], at: rowOrigins, typed: 0),
                chip: nil,
            ),
        ),
        OverlayScene(
            name: "outlined-with-chip",
            overlay: overlay(
                .rightClickInWindow,
                .outlined,
                hints: hints(["a", "s", "d", "fa", "fs", "fd"], at: rowOrigins, typed: 0),
                chip: HintLayout.chip(
                    for: CGRect(x: 20, y: 0, width: 240, height: 120),
                    in: canvas,
                ),
            ),
        ),
        OverlayScene(
            name: "clamped-at-the-edges",
            overlay: overlay(
                .rightClickInWindow,
                .outlined,
                hints: hints(
                    ["a", "fa", "s", "fs"],
                    at: [
                        CGPoint(x: 0, y: 50), CGPoint(x: -30, y: -15),
                        CGPoint(x: 290, y: 110), CGPoint(x: 0, y: 120),
                    ],
                    typed: 0,
                ),
                chip: HintLayout.chip(
                    for: CGRect(x: 200, y: -40, width: 200, height: 100),
                    in: canvas,
                ),
            ),
        ),
    ]

    /// Pixels per point: a Retina display's, fixed so the image does not depend on the
    /// machine that renders it.
    static let scale: CGFloat = 2

    /// Tags for `labels` on targets whose left edges sit at `origins`, with `typed`
    /// characters already typed on every tag.
    static func hints(_ labels: [String], at origins: [CGPoint], typed: Int) -> [PlacedHint] {
        zip(labels, origins).map { label, origin in
            let target = CGRect(origin: origin, size: CGSize(width: 60, height: 20))
            let placed = HintLayout.placedHint(label: label, targetFrame: target, in: canvas)
            return PlacedHint(
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
    /// separates a tag from a light background and the fill from a dark one.
    @MainActor
    static func image(of scene: OverlayScene) -> CGImage? {
        let size = scene.overlay.canvas.size
        let content = ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95)
                Color(.sRGB, red: 0.17, green: 0.17, blue: 0.18)
            }
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
