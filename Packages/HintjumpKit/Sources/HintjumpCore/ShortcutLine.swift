/// One of Getting Started's "Try it" lines: a trigger's current combination, drawn as a
/// key chip between a lead-in and what pressing it does, e.g. "Press ⌃⇧Space now:
/// labels appear on this window" (`docs/design/settings-window.md` › Getting Started).
///
/// Split around the chip, because the view draws the combination as a chip rather than
/// as text; ``sentence`` is the same line as plain text, for VoiceOver.
public struct ShortcutLine: Equatable, Identifiable, Sendable {
    /// The trigger this line teaches.
    public let entryPoint: EntryPoint
    /// The words before the chip.
    public let lead: String
    /// The combination as the chip shows it (``KeyCombination/displayText``).
    public let keys: String
    /// The words after the chip, starting with the space or the colon that follows it.
    public let rest: String

    public var id: EntryPoint {
        entryPoint
    }

    /// The whole line as text.
    public var sentence: String {
        "\(lead) \(keys)\(rest)"
    }

    /// The line for `entryPoint` while it is set to `combination`.
    init(entryPoint: EntryPoint, combination: KeyCombination) {
        self.entryPoint = entryPoint
        lead = "Press"
        keys = combination.displayText
        rest = Self.rest(for: entryPoint)
    }

    /// What pressing the trigger does, in the spec's words. Only the first line says
    /// "now": it is the one that works on the Settings window itself.
    private static func rest(for entryPoint: EntryPoint) -> String {
        switch entryPoint {
        case .appMenus:
            ": labels appear on the app menus in the menu bar"

        case .clickInWindow:
            " now: labels appear on this window"

        case .rightClickInWindow:
            ": the same labels, and the one you type is right-clicked"

        case .statusIcons:
            ": labels appear on the status icons in the menu bar"
        }
    }
}
