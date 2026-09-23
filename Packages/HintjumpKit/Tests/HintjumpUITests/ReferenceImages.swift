import CoreGraphics
import Foundation
import Testing

/// Where the reference images live, where a failed comparison leaves its evidence, and
/// whether this run records instead of comparing — shared by every rendering suite, so
/// each one records and compares the same way.
enum ReferenceImages {
    /// The environment variable that turns a run into a recording. `just record-snapshots`
    /// sets it; nothing else should. Any value other than empty, `0`, or `false` counts,
    /// like `RUN_LOCAL_MACHINE_TESTS`.
    static let recordVariable = "RECORD_SNAPSHOTS"

    /// How far a channel may move, out of 255, before its pixel counts as changed.
    ///
    /// Not zero: rendering the same view twice on the same machine moves a few dozen
    /// anti-aliased edge pixels by 1/255. Eight is far below anything a real change makes
    /// — a colour change, a dimmed character, or a tag moved by one point moves pixels by
    /// tens to hundreds (`a tag moved by one point is caught` holds that).
    static let tolerance = 8

    /// How many rows of pixels a failure's "where" line groups together.
    static let bandHeight = 40

    /// This test target's own directory, found from this file's path at compile time.
    private static let testsDirectory = URL(filePath: #filePath).deletingLastPathComponent()

    /// The committed reference images, one PNG per scene.
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

    static func reference(named name: String) -> URL {
        directory.appending(path: "\(name).png")
    }

    /// Compares `rendered` pixel by pixel with the reference image `name`, recording an
    /// issue that says what changed and where the evidence went — or, under
    /// `just record-snapshots`, writes `rendered` as the new reference instead.
    static func check(_ rendered: CGImage, named name: String) throws {
        let actual = try RGBAPixels(rendered)
        let referenceURL = reference(named: name)

        if isRecording {
            let image = try #require(actual.image(), "could not re-encode \(name)")
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
            \(name) rendered at \(actual.width)×\(actual.height) px, but its reference \
            is \(reference.width)×\(reference.height) px.
            """,
        )

        let difference = PixelDifference(actual: actual, reference: reference, tolerance: tolerance)
        guard difference.differingPixels > 0 else {
            return
        }
        let evidence = writeEvidence(named: name, actual: actual, difference: difference)
        let bands = difference.changedBands(bandHeight: bandHeight).joined(separator: "; ")
        Issue.record("""
        \(name): \(difference.differingPixels) of \(actual.width * actual.height) pixels \
        differ from \(referenceURL.lastPathComponent) (largest channel change \
        \(difference.largestChannelDelta)/255). Where: \(bands). \(evidence) If the change is \
        intended, run `just record-snapshots` and review the new image in the pull request.
        """)
    }

    /// Writes the rendered image and the highlighted difference, and says where they went.
    private static func writeEvidence(
        named name: String,
        actual: RGBAPixels,
        difference: PixelDifference,
    ) -> String {
        let actualURL = failuresDirectory.appending(path: "\(name).actual.png")
        let diffURL = failuresDirectory.appending(path: "\(name).diff.png")
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
}
