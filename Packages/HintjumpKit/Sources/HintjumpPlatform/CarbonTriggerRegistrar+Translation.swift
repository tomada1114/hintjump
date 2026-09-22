import Carbon.HIToolbox
import HintjumpCore

/// The config vocabulary in Carbon's terms: a ``HintjumpCore/KeyName`` as a virtual key
/// code, and a set of ``HintjumpCore/KeyModifier``s as a Carbon modifier mask.
///
/// The key codes are ANSI key *positions*, not characters: `a` is the key where a US
/// layout has `A`. That is the ABC-input-source assumption `docs/decisions.md` already
/// makes for typing labels, and it is why no layout lookup happens here. Every value is
/// a `kVK_*` constant from `Carbon.HIToolbox`, never a numeric literal.
extension CarbonTriggerRegistrar {
    /// Every name ``HintjumpCore/KeyName/parse(_:)`` accepts, to its virtual key code.
    static let keyCodes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
        "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket, "\\": kVK_ANSI_Backslash,
        ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
        ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        "`": kVK_ANSI_Grave,
    ]

    /// The virtual key code for `key`, or `nil` for a name the table does not have —
    /// which the local-machine test proves never happens for a parsed ``KeyName``.
    static func keyCode(for key: KeyName) -> UInt32? {
        keyCodes[key.rawValue].map(UInt32.init)
    }

    /// The Carbon modifier mask for `modifiers` — `cmdKey` and friends, not
    /// `CGEventFlags`, which is a different bit layout.
    static func modifierMask(for modifiers: Set<KeyModifier>) -> UInt32 {
        modifiers.reduce(into: UInt32.zero) { mask, modifier in
            mask |= UInt32(carbonMask(for: modifier))
        }
    }

    private static func carbonMask(for modifier: KeyModifier) -> Int {
        switch modifier {
        case .command:
            cmdKey

        case .control:
            controlKey

        case .option:
            optionKey

        case .shift:
            shiftKey
        }
    }
}
