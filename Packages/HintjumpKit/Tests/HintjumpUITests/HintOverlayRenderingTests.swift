import CoreGraphics
import Foundation
import HintjumpCore
@testable import HintjumpUI
import SwiftUI
import Testing

/// Where the reference images live, where a failed comparison leaves its evidence, and
/// whether this run records instead of comparing.
enum ReferenceImages {
    /// The environment variable that turns a run into a recording. `just record-snapshots`
    /// sets it; nothing else should. Any value other than empty, `0`, or `false` counts,
    /// like `RUN_LOCAL_MACHINE_TESTS`.
    static let recordVariable = "RECORD_SNAPSHOTS"

    /// This test target's own directory, found from this file's path at compile time.
    private static let testsDirectory = URL(filePath: #filePath).deletingLastPathComponent()

    /// The committed reference images, one PNG per ``OverlayScene``.
    static let directory = testsDirectory.appending(path: "References")

    /// Where a failed comparison writes the rendered image and the difference: under the
    /// package's `.build`, which is gitignored and never committed.
    static let failuresDirectory = testsDirectory
        .appending(path: "../../.build/snapshot-failures")
        .standardizedFileURL

    static var isRecording: Bool {
        guard let raw = ProcessInfo.processInfo.environment[recordVariable] else {
            return false
        }
        return !["", "0", "false"].contains(raw)
    }

    static func reference(for scene: OverlayScene) -> URL {
        directory.appending(path: "\(scene.name).png")
    }
}

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
    /// How far a channel may move, out of 255, before its pixel counts as changed.
    ///
    /// Not zero: rendering the same view twice on the same machine moves a few dozen
    /// anti-aliased edge pixels by 1/255. Eight is far below anything a real change makes
    /// — a colour change, a dimmed character, or a tag moved by one point moves pixels by
    /// tens to hundreds (`a tag moved by one point is caught` below holds that).
    static let tolerance = 8

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
                isSingle: placed.isSingle,
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
    /// and dark content alike, so an image of the tags alone would hide the halo that cuts
    /// them out of a dark background.
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

    /// Writes the rendered image and the highlighted difference, and says where they went.
    private static func writeEvidence(
        of scene: OverlayScene,
        actual: RGBAPixels,
        difference: PixelDifference,
    ) -> String {
        let directory = ReferenceImages.failuresDirectory
        let actualURL = directory.appending(path: "\(scene.name).actual.png")
        let diffURL = directory.appending(path: "\(scene.name).diff.png")
        do {
            guard let actualImage = actual.image(),
                  let diffImage = difference.highlighted.image()
            else {
                return "The images could not be re-encoded, so none were written."
            }
            try PNGFile.write(actualImage, to: actualURL)
            try PNGFile.write(diffImage, to: diffURL)
        } catch {
            return "Writing the evidence failed: \(error)."
        }
        return "Rendered: \(actualURL.path); changed pixels in red: \(diffURL.path)."
    }

    @Test(arguments: Self.scenes)
    @MainActor
    func `renders exactly as its reference image`(scene: OverlayScene) throws {
        let rendered = try #require(
            Self.image(of: scene),
            "ImageRenderer produced no image for \(scene.name)",
        )
        let actual = try RGBAPixels(rendered)
        let referenceURL = ReferenceImages.reference(for: scene)

        if ReferenceImages.isRecording {
            let image = try #require(actual.image(), "could not re-encode \(scene.name)")
            try PNGFile.write(image, to: referenceURL)
            return
        }
        guard FileManager.default.fileExists(atPath: referenceURL.path) else {
            Issue.record("""
            No reference image at \(referenceURL.path). Run `just record-snapshots`, look at \
            the new PNG, and commit it.
            """)
            return
        }
        let reference = try RGBAPixels(PNGFile.read(referenceURL))
        try #require(
            actual.width == reference.width && actual.height == reference.height,
            """
            \(scene.name) rendered at \(actual.width)×\(actual.height) px, but its reference \
            is \(reference.width)×\(reference.height) px.
            """,
        )

        let difference = PixelDifference(
            actual: actual,
            reference: reference,
            tolerance: Self.tolerance,
        )

        guard difference.differingPixels > 0 else {
            return
        }
        let evidence = Self.writeEvidence(of: scene, actual: actual, difference: difference)
        Issue.record("""
        \(scene.name): \(difference.differingPixels) of \(actual.width * actual.height) pixels \
        differ from \(referenceURL.lastPathComponent) (largest channel change \
        \(difference.largestChannelDelta)/255). \(evidence) If the change is intended, run \
        `just record-snapshots` and review the new image in the pull request.
        """)
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
            isSingle: first.isSingle,
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
            tolerance: Self.tolerance,
        )

        #expect(difference.differingPixels > 0)
    }
}
