import CoreGraphics
import HintjumpCore

/// The fake every Core test of ``TopmostContainerProbing`` uses: answers every `signals`
/// call with the signals it was built with, and counts the calls
/// (`.claude/rules/testing.md` › Fakes, not mocks). `@MainActor`, like the port's method.
@MainActor
final class FakeTopmostContainerProbe: TopmostContainerProbing {
    /// Nothing on top: the frontmost application has focus and no window above the
    /// normal layer is on screen — the signals of a plain window.
    static let nothingOnTop = TopmostContainerSignals(
        focusedApplicationPID: nil,
        menuBarHeight: menuBarHeight,
        raisedWindows: [],
    )
    /// A 2,560 × 1,440 display's menu bar.
    private static let menuBarHeight: CGFloat = 24

    /// How many times `signals` was called.
    private(set) var signalsCount = 0
    private let answer: TopmostContainerSignals

    /// Answers every call with ``nothingOnTop``.
    convenience init() {
        self.init(answering: Self.nothingOnTop)
    }

    /// Answers every call with `signals`.
    init(answering signals: TopmostContainerSignals) {
        answer = signals
    }

    func signals() -> TopmostContainerSignals {
        signalsCount += 1
        return answer
    }
}
