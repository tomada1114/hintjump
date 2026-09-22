/// One key typed while hints are shown, as the matcher sees it.
///
/// Characters, never key codes (`docs/decisions.md` › "Labels are ASCII letters; the user
/// types with an ABC input source"). The caller lowercases a character first; the matcher
/// compares exactly, so an upper-case character matches nothing.
public enum HintKey: Equatable, Sendable {
    /// Backspace: undo the last narrowing.
    case backspace
    /// A typed character.
    case character(Character)
    /// Esc: close the hints without clicking.
    case escape
}

/// What typing one key meant: the key-handling state machine behind the hint overlay.
///
/// A value: every key goes through ``handle(_:)``, which updates the state and says what
/// the key did, with no timing and no reference to the targets — a selection names its
/// label, which ``LabelAssignment/target(labeled:)`` turns back into a target.
///
/// A character that completes a label selects it; one that is the start of longer labels
/// narrows to them; anything else is ignored and changes nothing, so a stray key (an IME
/// character, a digit) never closes the hints. Backspace undoes a narrowing; Esc cancels
/// from any point. Once a label is selected or the hints are cancelled, every further key
/// is ignored.
public struct HintMatcher: Equatable, Sendable {
    /// Where the matcher is.
    public enum Phase: Equatable, Sendable {
        /// Waiting for the next character.
        case matching
        /// The label that was typed in full.
        case selected(String)
        /// Esc was pressed.
        case cancelled
    }

    /// What one key did.
    public enum Outcome: Equatable, Sendable {
        /// The character started longer labels; ``candidates`` now holds only those.
        case narrowed
        /// Backspace undid a narrowing; ``candidates`` holds what it held before it.
        case widened
        /// The character completed this label: click its target.
        case selected(String)
        /// Esc: close the hints.
        case cancelled
        /// The key meant nothing here, and the state is unchanged.
        case ignored
    }

    /// Every label shown when the hints appeared, in rank order.
    public let labels: [String]
    /// The characters typed so far toward a longer label: empty, or a prefix of at least
    /// one label — what the overlay dims in the hints it still shows.
    public private(set) var typed: String
    /// Where the matcher is.
    public private(set) var phase: Phase

    /// The labels still reachable, in rank order: those starting with ``typed`` while
    /// matching, and none once a label is selected or the hints are cancelled.
    public var candidates: [String] {
        guard phase == .matching else {
            return []
        }
        return labels.filter { $0.hasPrefix(typed) }
    }

    /// A matcher over `labels`, with nothing typed yet.
    ///
    /// `labels` are expected to be distinct with none a prefix of another, as
    /// ``LabelAssigner`` hands them out; if one is a prefix of another anyway, typing it
    /// selects it and the longer label becomes unreachable.
    public init(labels: [String]) {
        self.labels = labels
        typed = ""
        phase = .matching
    }

    /// Applies `key` and says what it did.
    public mutating func handle(_ key: HintKey) -> Outcome {
        guard phase == .matching else {
            return .ignored
        }
        switch key {
        case let .character(character):
            return type(character)

        case .backspace:
            guard !typed.isEmpty else {
                return .ignored
            }
            typed.removeLast()
            return .widened

        case .escape:
            phase = .cancelled
            return .cancelled
        }
    }

    private mutating func type(_ character: Character) -> Outcome {
        let attempt = typed + String(character)
        if labels.contains(attempt) {
            phase = .selected(attempt)
            return .selected(attempt)
        }
        guard labels.contains(where: { $0.hasPrefix(attempt) }) else {
            return .ignored
        }
        typed = attempt
        return .narrowed
    }
}
