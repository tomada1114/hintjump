/// A modifier in the configuration file's vocabulary.
///
/// The raw values are what a user types (`ctrl+shift+space`), not what macOS calls
/// them: this type is the config contract, and translating it into a Carbon modifier
/// mask belongs to the trigger adapter in `HintjumpPlatform`.
public enum KeyModifier: String, CaseIterable, Comparable, Sendable {
    case command = "cmd"
    case control = "ctrl"
    case option = "alt"
    case shift

    /// The order a combination is written and rendered in, which is the order a user
    /// reads on a Mac keyboard rather than the alphabetical order of the cases.
    public static let writingOrder: [Self] = [.control, .option, .shift, .command]

    public static func < (lhs: Self, rhs: Self) -> Bool {
        guard let left = writingOrder.firstIndex(of: lhs),
              let right = writingOrder.firstIndex(of: rhs)
        else {
            return false
        }
        return left < right
    }
}

/// The non-modifier key of a combination, validated against the documented vocabulary
/// and kept as the name the file spells.
///
/// A name rather than a key code: the file is written by a person, and the mapping to
/// a virtual key code is one adapter's translation, which would drag a Carbon import
/// into Core if it lived here.
public struct KeyName: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// The highest function key in the vocabulary.
    static let highestFunctionKey = 12

    /// The names that are not a single character.
    static let named: Set<String> = Set(
        ["space", "return", "tab"] + (1 ... highestFunctionKey).map { "f\($0)" },
    )

    /// The punctuation keys a US layout has as one unshifted key.
    static let punctuation: Set<Character> = [
        "-",
        "=",
        "[",
        "]",
        "\\",
        ";",
        "'",
        ",",
        ".",
        "/",
        "`",
    ]

    /// The names the built-in defaults are made of, constructed without a parse that
    /// could fail — see ``HintjumpConfig/default``.
    public static let space = Self(unchecked: "space")
    static let letterM = Self(unchecked: "m")
    static let letterS = Self(unchecked: "s")

    /// The lower-cased name, exactly as it is written in the file.
    public let rawValue: String

    public var description: String {
        rawValue
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    /// The key `text` names, or `nil` when the vocabulary does not have it.
    public static func parse(_ text: String) -> Self? {
        let lowered = text.lowercased()
        if Self.named.contains(lowered) {
            return Self(unchecked: lowered)
        }
        guard let character = lowered.first, lowered.count == 1 else {
            return nil
        }
        let isSingleKey = character.isASCII
            && (character.isLetter || character.isNumber || Self.punctuation.contains(character))
        guard isSingleKey else {
            return nil
        }
        return Self(unchecked: lowered)
    }
}

/// Why a `"ctrl+shift+space"` string is not a combination.
///
/// Separate from ``ConfigError`` because the combination does not know its line; the
/// schema attaches one when it turns this into the error a user reads.
public enum KeyCombinationSyntaxError: Error, Equatable, Sendable {
    case duplicateModifier(KeyModifier)
    case empty
    case noModifier(String)
    case unknownKey(String)
    case unknownModifier(String)

    /// The ``ConfigError/reason`` this becomes.
    public var reason: String {
        switch self {
        case let .duplicateModifier(modifier):
            "the modifier `\(modifier.rawValue)` is repeated"

        case .empty:
            "a trigger cannot be empty"

        case let .noModifier(text):
            "`\(text)` has no modifier — every trigger needs at least one of ctrl, alt, shift, cmd"

        case let .unknownKey(name):
            "unknown key `\(name)` — use a letter, a digit, space, return, tab, f1-f12, "
                + "or one of - = [ ] \\ ; ' , . / `"

        case let .unknownModifier(name):
            "unknown modifier `\(name)` — use ctrl, alt, shift, or cmd"
        }
    }
}

/// A trigger: one or more modifiers and one key, as `ctrl+shift+space`.
public struct KeyCombination: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let modifiers: Set<KeyModifier>
    public let key: KeyName

    /// The combination written the way the configuration file writes it, modifiers in
    /// the canonical `ctrl+alt+shift+cmd` order.
    public var description: String {
        (modifiers.sorted().map(\.rawValue) + [key.rawValue]).joined(separator: "+")
    }

    public init(modifiers: Set<KeyModifier>, key: KeyName) {
        self.modifiers = modifiers
        self.key = key
    }

    /// Parses the `"ctrl+shift+space"` form.
    ///
    /// The last `+`-separated part is the key and every earlier one a modifier, so the
    /// vocabulary's absence of a `+` key is what keeps the split unambiguous.
    public static func parse(_ text: String) throws(KeyCombinationSyntaxError) -> Self {
        guard !text.isEmpty else {
            throw .empty
        }
        let parts = text.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else {
            throw .noModifier(text)
        }
        var parsed: Set<KeyModifier> = []
        for part in parts.dropLast() {
            guard let modifier = KeyModifier(rawValue: part.lowercased()) else {
                throw .unknownModifier(part)
            }
            guard parsed.insert(modifier).inserted else {
                throw .duplicateModifier(modifier)
            }
        }
        let name = parts[parts.count - 1]
        guard let parsedKey = KeyName.parse(name) else {
            throw .unknownKey(name)
        }
        return Self(modifiers: parsed, key: parsedKey)
    }
}
