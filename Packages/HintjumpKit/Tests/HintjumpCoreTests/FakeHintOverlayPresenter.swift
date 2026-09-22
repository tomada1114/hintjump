import CoreGraphics
import HintjumpCore

/// The fake every Core test of ``HintOverlayPresenting`` uses: a screen of a fixed frame,
/// and a record of every `show` — with the handlers it was given, so a test can type at
/// the overlay or dismiss it as the panel would — and of how often `hide` was called.
@MainActor
final class FakeHintOverlayPresenter: HintOverlayPresenting {
    /// One `show` call.
    struct Shown {
        let canvas: CGRect
        let onKey: @MainActor (HintKey) -> Void
        let onDismiss: @MainActor () -> Void
    }

    /// Every `show`, in order.
    private(set) var shows: [Shown] = []
    /// How many times `hide` was called.
    private(set) var hideCount = 0
    /// Every point `screenFrame(containing:)` was asked about.
    private(set) var screenQueries: [CGPoint] = []
    /// What `screenFrame(containing:)` answers, for any point.
    let screen: CGRect?

    init(screen: CGRect?) {
        self.screen = screen
    }

    func screenFrame(containing point: CGPoint) -> CGRect? {
        screenQueries.append(point)
        return screen
    }

    func show(
        canvas: CGRect,
        onKey: @escaping @MainActor (HintKey) -> Void,
        onDismiss: @escaping @MainActor () -> Void,
    ) {
        shows.append(Shown(canvas: canvas, onKey: onKey, onDismiss: onDismiss))
    }

    func hide() {
        hideCount += 1
    }

    /// Types `key` at the most recent `show`, as the panel would.
    func type(_ key: HintKey) {
        shows.last?.onKey(key)
    }

    /// Types each character of `text` in turn.
    func type(_ text: String) {
        for character in text {
            type(.character(character))
        }
    }

    /// Dismisses the most recent `show`, as the panel losing key status would.
    func dismiss() {
        shows.last?.onDismiss()
    }
}
