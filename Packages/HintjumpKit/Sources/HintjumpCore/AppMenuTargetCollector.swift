import CoreGraphics

/// The app-menus entry point's collector: the frontmost application's menu bar titles —
/// the Apple menu, the app menu, File, Edit, and the rest — in the order the bar shows
/// them.
///
/// It reads ``ReadScope/menuBar`` with ``ReadStrategy/batched`` and a depth limit of 1:
/// every closed menu under a title still publishes its items to Accessibility, so the
/// whole bar is hundreds of elements when only its dozen titles are wanted. Nothing is
/// pruned by visibility because every title is on the bar, and nothing is woken because
/// a menu bar is native even in a Chromium or Electron app, so the reader is used
/// directly rather than through ``ManualAccessibilityWaker``.
///
/// The titles are ranked in bar order, left to right, not by ``TargetRanker``: a real
/// menu bar has fewer titles than there are single-character labels, so every title gets
/// one and the order only decides which character (`docs/decisions.md` › "The menu-bar
/// entry points stay"). Once a title is clicked open, macOS's own keys take over the
/// menu; nothing here labels what opened (`docs/decisions.md` › "The frontmost entry
/// point targets whatever is on top; after a click, macOS takes over").
@MainActor
public final class AppMenuTargetCollector: HintTargetCollecting {
    /// The role a menu bar title reports.
    static let titleRole = "AXMenuBarItem"
    /// How many levels below the bar the read descends: the titles and nothing under them.
    static let titleDepth = 1
    /// A title no wider or no taller than this is a sliver — one the bar has squeezed out,
    /// behind a notch or past the status items — not something on screen to click.
    static let sliverExtent: CGFloat = 2

    private let reader: any AccessibilityTreeReading

    /// Reads through `reader`.
    public init(reader: any AccessibilityTreeReading) {
        self.reader = reader
    }

    /// Whether `element`, read under a bar, is one of its titles a hint can go on:
    /// a direct child of the bar with the title role, enabled, and bigger than a sliver.
    private static func isTitle(_ element: ElementSnapshot) -> Bool {
        guard element.parentIndex == 0,
              element.role == titleRole,
              element.isEnabled,
              let frame = element.frame
        else {
            return false
        }
        return frame.width > sliverExtent && frame.height > sliverExtent
    }

    /// The menu bar's titles, left to right.
    ///
    /// The bar's own frame is the ``TargetSet/rootFrame``, so a title is clicked at the
    /// center of its part on the bar. A bar that reports no frame yields an empty set
    /// with a zero root frame, as a frameless window does for ``WindowTargetCollector``.
    /// An `app` with no process identifier names no process, so it throws
    /// ``AccessibilityReadError/noSuchProcess(_:)`` with pid 0 without reading; the
    /// session never passes one.
    public func collect(from app: FrontmostApp) throws -> TargetSet {
        guard let pid = app.processIdentifier else {
            throw AccessibilityReadError.noSuchProcess(0)
        }
        let snapshot = try reader.readTree(
            pid: pid,
            scope: .menuBar,
            strategy: .batched,
            maxDepth: Self.titleDepth,
        )
        let rootFrame = snapshot.elements.first?.frame ?? .zero
        let targets = snapshot.elements.filter(Self.isTitle).compactMap { element -> HintTarget? in
            guard let frame = element.frame,
                  let clickPoint = ClickPointRule.point(for: frame, within: rootFrame)
            else {
                return nil
            }
            return HintTarget(frame: frame, clickPoint: clickPoint, role: element.role)
        }
        return TargetSet(
            pid: pid,
            bundleIdentifier: snapshot.bundleIdentifier,
            rootFrame: rootFrame,
            targets: targets,
            readDuration: snapshot.readDuration,
        )
    }
}
