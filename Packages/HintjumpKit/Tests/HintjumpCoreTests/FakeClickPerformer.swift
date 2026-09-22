import CoreGraphics
import HintjumpCore

/// The fake every Core test of ``ClickPerforming`` uses: records each click, and throws
/// a planted error after recording it.
@MainActor
final class FakeClickPerformer: ClickPerforming {
    /// One posted click.
    struct Click: Equatable {
        let point: CGPoint
        let button: MouseButton
    }

    /// Every click asked for, in order, whether or not it threw.
    private(set) var clicks: [Click] = []
    /// Thrown from every click when set.
    var error: ClickError?

    func click(at point: CGPoint, button: MouseButton) throws(ClickError) {
        clicks.append(Click(point: point, button: button))
        if let error {
            throw error
        }
    }
}
