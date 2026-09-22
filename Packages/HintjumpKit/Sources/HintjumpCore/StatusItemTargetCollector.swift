import CoreGraphics

/// The status-items entry point's collector: every visible item in the menu bar, left to
/// right, whichever process it belongs to.
///
/// It never reads the frontmost app — the items come from ``StatusItemListing``'s one
/// look at the window server — so it reports ``readsFrontmostApp`` as `false` and the
/// session hands it a press even while Hintjump itself is frontmost. The app it is
/// handed only names the press in the log. Hintjump's own status item is a target like
/// any other.
public struct StatusItemTargetCollector: HintTargetCollecting {
    /// A window this thin, or thinner, either way is not something a person clicks.
    private static let minimumSide: CGFloat = 2
    /// How far an item may reach past its visible segment and still count as inside it.
    /// macOS 26 draws the clock 2 pt past the screen's right edge (x 1569 + 143 on a
    /// 1710 pt screen), and it is fully visible; an item behind the camera housing or
    /// off the screen is hidden by far more than this.
    private static let overhangTolerance: CGFloat = 4

    private let listing: any StatusItemListing

    /// `false`: the targets come from the menu bar, not from the frontmost app.
    public var readsFrontmostApp: Bool {
        false
    }

    /// Scans the menu bar through `listing` on every press.
    public init(listing: any StatusItemListing) {
        self.listing = listing
    }

    /// Whether `frame` is a status item a hint can be put on: more than 2 pt wide and
    /// tall, and inside one visible part of the bar give or take ``overhangTolerance`` —
    /// so an item hidden behind a camera housing, or pushed off the screen, gets no hint.
    private static func isVisibleItem(_ frame: CGRect, in scan: StatusItemScan) -> Bool {
        frame.width > minimumSide
            && frame.height > minimumSide
            && scan.visibleSegments.contains { segment in
                segment.insetBy(dx: -overhangTolerance, dy: -overhangTolerance).contains(frame)
            }
    }

    /// The visible items, left to right, each clicked at its center; an empty set rooted
    /// at `.zero` when there is no screen, which the session shows nothing for.
    public func collect(from app: FrontmostApp) -> TargetSet {
        let clock = ContinuousClock()
        let start = clock.now
        let scan = listing.scan()
        let readDuration = start.duration(to: clock.now)
        let pid = app.processIdentifier ?? 0
        guard let scan else {
            return TargetSet(
                pid: pid,
                bundleIdentifier: app.bundleIdentifier,
                rootFrame: .zero,
                targets: [],
                readDuration: readDuration,
            )
        }
        let frames = scan.windows
            .map(\.frame)
            .filter { Self.isVisibleItem($0, in: scan) }
            .reduce(into: [CGRect]()) { kept, frame in
                if !kept.contains(frame) {
                    kept.append(frame)
                }
            }
            .sorted { ($0.minX, $0.minY) < ($1.minX, $1.minY) }
        let targets = frames.compactMap { frame -> HintTarget? in
            guard let clickPoint = ClickPointRule.point(for: frame, within: scan.barFrame) else {
                return nil
            }
            return HintTarget(frame: frame, clickPoint: clickPoint, role: nil)
        }
        return TargetSet(
            pid: pid,
            bundleIdentifier: app.bundleIdentifier,
            rootFrame: scan.barFrame,
            targets: targets,
            readDuration: readDuration,
        )
    }
}
