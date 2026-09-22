import CoreGraphics
import Foundation

/// What a ``HintTargetCollecting`` found for one trigger press.
public struct TargetSet: Equatable, Sendable {
    /// The process the targets were read from.
    public let pid: pid_t
    /// That process's bundle identifier, when it has one.
    public let bundleIdentifier: String?
    /// The frame of what was read — for a window entry point, the window. The overlay
    /// picks its screen by this frame's center and the right-click chip sits on it.
    public let rootFrame: CGRect
    /// The targets in rank order, likeliest first: the order labels are handed out in.
    public let targets: [HintTarget]
    /// What the read behind this set cost, as the reader measured it.
    public let readDuration: Duration

    public init(
        pid: pid_t,
        bundleIdentifier: String?,
        rootFrame: CGRect,
        targets: [HintTarget],
        readDuration: Duration,
    ) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.rootFrame = rootFrame
        self.targets = targets
        self.readDuration = readDuration
    }
}
