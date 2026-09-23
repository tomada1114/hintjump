import CoreGraphics
import HintjumpCore
import Testing

/// One overlay state worth a reference image: the file name it is recorded under, the
/// targets its tags label, and the state itself. The scenes are defined in
/// `HintOverlayRenderingTests.swift`.
struct OverlayScene: CustomTestStringConvertible {
    /// The reference image's file name, without the extension.
    let name: String
    /// The targets' frames, in global coordinates, outlined under the tags so the image
    /// shows where each tag sits on its target.
    let targets: [CGRect]
    let overlay: HintOverlayState

    var testDescription: String {
        name
    }
}
