import CoreGraphics

/// One tag to place: the label it shows and the frame, in global top-left-origin
/// coordinates, of the target it labels.
public struct LabeledFrame: Equatable, Sendable {
    /// The label, as the user types it.
    public let label: String
    /// The target's whole frame; ``HintLayout`` anchors on the part of it inside the root.
    public let frame: CGRect

    public init(label: String, frame: CGRect) {
        self.label = label
        self.frame = frame
    }
}
