import AppKit
import HintjumpCore

/// The window the hint overlay is drawn in: a borderless, transparent, click-through
/// panel that can become the key window without activating Hintjump.
///
/// Becoming key is how it receives the label the user types without Input Monitoring —
/// a key window gets its keystrokes from the window server, where a global key tap
/// would need the grant — and `.nonactivatingPanel` is what lets it be key while the
/// app being clicked stays the active app, keeping its menu bar and its focused control
/// (`docs/decisions.md` › "The overlay is a key, non-activating panel that reads typed
/// characters").
///
/// Translation only: a key-down becomes a ``HintjumpCore/HintKey`` read from its
/// characters — never its key code — and losing key status is reported as it happens.
/// What either means is ``HintjumpCore/HintSession``'s decision.
@MainActor
final class HintOverlayPanel: NSPanel {
    /// Receives each key typed while the panel is key.
    var onKey: (@MainActor (HintKey) -> Void)?
    /// Called when the panel stops being the key window.
    var onResignKey: (@MainActor () -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    /// A panel sized later, by each `show`: the overlay covers whichever screen holds
    /// the target window, so there is no frame worth giving it up front.
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
        )
        becomesKeyOnlyIfNeeded = false
        // Above the menu bar and above an open menu, so hints are never drawn underneath
        // what they label.
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // The tags are only drawn: a mouse click passes through to the app underneath,
        // which takes key status and so dismisses the hints.
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .none
        // Owned by its presenter through ARC, not by AppKit.
        isReleasedWhenClosed = false
        // `sharingType` stays at its default: the overlay shows in a screen share
        // (`docs/decisions.md` › "Four small questions closed for the first release").
    }

    /// The key an event's characters stand for, or `nil` for one that is none of them.
    ///
    /// Esc and both backspace characters (delete, `0x7F`, and backspace, `0x08`) are the
    /// session's two control keys; any other single character is handed on as typed, and
    /// an event with none or several (a dead key's composition) is dropped.
    static func hintKey(fromCharacters characters: String?) -> HintKey? {
        guard let characters, characters.count == 1, let character = characters.first else {
            return nil
        }
        switch character {
        case "\u{1B}":
            return .escape

        case "\u{7F}", "\u{08}":
            return .backspace

        default:
            return .character(character)
        }
    }

    /// Takes every key event for the overlay: a key-down (not an auto-repeat) becomes a
    /// ``HintjumpCore/HintKey``, a key-up or a modifier change is swallowed, and anything
    /// else is AppKit's as usual.
    ///
    /// `charactersIgnoringModifiers`, because the trigger's Control or Option may still be
    /// held when the first label character is typed; Shift still applies to it, which is
    /// why the session lowercases.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            guard !event.isARepeat,
                  let key = Self.hintKey(fromCharacters: event.charactersIgnoringModifiers)
            else {
                return
            }
            onKey?(key)

        case .flagsChanged, .keyUp:
            return

        default:
            super.sendEvent(event)
        }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
