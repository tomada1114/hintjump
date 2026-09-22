import AppKit
import HintjumpCore

/// The `NSPanel`-backed adapter for ``HintjumpCore/HintOverlayPresenting``.
///
/// Translation only: the port speaks global top-left-origin coordinates — the
/// Accessibility API's, in which every target frame arrives — and AppKit speaks
/// bottom-left-origin ones, so every frame crossing this adapter is flipped against the
/// primary screen's height, the one screen whose top-left corner is the origin of both.
/// Which screen to cover, what is drawn, and what a key means are
/// ``HintjumpCore/HintSession``'s decisions.
///
/// The panel's content arrives through ``install(contentView:)`` rather than being built
/// here, because the view lives in `HintjumpUI` and this module must not import it
/// (`docs/architecture.md` › Layers).
@MainActor
public final class PanelHintOverlayPresenter: HintOverlayPresenting {
    /// The overlay window; internal so the local-machine test can see what was shown.
    let panel = HintOverlayPanel()

    public init() {
        // The panel is created ordered out; nothing is shown until `show`.
    }

    /// `rect` flipped between the port's top-left-origin space and AppKit's
    /// bottom-left-origin one. The flip is its own inverse, so it serves both ways.
    private static func flipped(_ rect: CGRect, primaryScreenHeight height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The primary screen's height, or `nil` without a display.
    private static func primaryScreenHeight() -> CGFloat? {
        NSScreen.screens.first?.frame.height
    }

    /// Makes `contentView` the overlay's content: the view that renders the session's
    /// overlay state, built by the composition root.
    public func install(contentView: NSView) {
        panel.contentView = contentView
    }

    public func screenFrame(containing point: CGPoint) -> CGRect? {
        guard let height = Self.primaryScreenHeight() else {
            return nil
        }
        return NSScreen.screens
            .lazy
            .map { Self.flipped($0.frame, primaryScreenHeight: height) }
            .first { $0.contains(point) }
    }

    /// Covers `canvas`, then makes the panel key without activating Hintjump.
    ///
    /// Never `NSApp.activate`: the app being clicked has to stay active, or its menu bar
    /// and its focused control would be gone by the time the click lands.
    public func show(
        canvas: CGRect,
        onKey: @escaping @MainActor (HintKey) -> Void,
        onDismiss: @escaping @MainActor () -> Void,
    ) {
        guard let height = Self.primaryScreenHeight() else {
            AppLog.hints.error("overlay not shown: no screen")
            return
        }
        // Handlers first, so a key typed the moment the panel turns key has somewhere to go.
        panel.onKey = onKey
        panel.onResignKey = onDismiss
        panel.setFrame(Self.flipped(canvas, primaryScreenHeight: height), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Forgets the handlers, then orders the panel out — in that order, so the loss of
    /// key status the ordering out causes is not reported as a dismissal.
    public func hide() {
        panel.onKey = nil
        panel.onResignKey = nil
        panel.orderOut(nil)
    }
}
