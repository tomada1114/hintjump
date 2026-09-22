import CoreGraphics

/// A port: put the hint overlay on screen, take the keys typed at it, and take it down.
///
/// Showing a window and reading keystrokes are AppKit's, so they live in a
/// `HintjumpPlatform` adapter; what is drawn and what a key means stay in Core
/// (``HintSession``). The adapter hands keys over as ``HintKey`` — characters, never key
/// codes (`docs/decisions.md` › "Labels are ASCII letters; the user types with an ABC
/// input source") — and does not lowercase them: that is the session's decision.
/// `@MainActor` because a window and its key events are.
@MainActor
public protocol HintOverlayPresenting: Sendable {
    /// The frame, in global top-left-origin coordinates (the Accessibility API's), of
    /// the screen that contains `point`, or `nil` when no screen does. The overlay covers
    /// that one screen: multi-monitor support is a non-goal, so a window straddling two
    /// screens gets hints on the one holding its center.
    func screenFrame(containing point: CGPoint) -> CGRect?

    /// Shows the overlay over `canvas` (global, top-left-origin) and starts taking keys.
    ///
    /// Every key typed while it is shown goes to `onKey`. `onDismiss` is for the overlay
    /// going away without being asked — it lost key status to a mouse click elsewhere or
    /// an app switch — and is never called for a ``hide()``. A second `show` replaces
    /// both handlers.
    func show(
        canvas: CGRect,
        onKey: @escaping @MainActor (HintKey) -> Void,
        onDismiss: @escaping @MainActor () -> Void,
    )

    /// Takes the overlay down and forgets the handlers `show` was given.
    func hide()
}
