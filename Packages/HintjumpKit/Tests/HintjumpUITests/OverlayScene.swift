import HintjumpCore
import Testing

/// One overlay state worth a reference image: the file name it is recorded under, and the
/// state itself. The scenes are defined in `HintOverlayRenderingTests+Scenes.swift`.
struct OverlayScene: CustomTestStringConvertible {
    /// The reference image's file name, without the extension.
    let name: String
    let overlay: HintOverlayState

    var testDescription: String {
        name
    }
}
