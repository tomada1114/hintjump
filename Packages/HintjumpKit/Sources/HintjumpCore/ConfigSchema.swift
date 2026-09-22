/// The schema: which sections and keys exist, what type each holds, and every rule a
/// syntactically valid file can still break.
///
/// Separate from ``TOMLSubset`` because they refuse different things — the parser
/// refuses text that is not the accepted grammar, this refuses a well-formed file that
/// says something the app cannot act on — and both report the same line-numbered
/// ``ConfigError`` so the Status window shows one kind of message.
public enum ConfigSchema {
    static let triggersSection = "triggers"
    static let hintsSection = "hints"
    static let appsSection = "apps"
    static let startupSection = "startup"

    static let clickInWindow = "click_in_window"
    static let rightClickInWindow = "right_click_in_window"
    static let appMenus = "app_menus"
    static let statusIcons = "status_icons"
    static let characters = "characters"
    static let disabled = "disabled"
    static let launchAtLogin = "launch_at_login"

    /// The fewest hint characters a useful label alphabet can have: below this, a
    /// two-character label covers too few elements to be worth showing.
    static let minimumHintCharacters = 8

    /// Every key each section accepts.
    static let keys: [String: [String]] = [
        triggersSection: [clickInWindow, rightClickInWindow, appMenus, statusIcons],
        hintsSection: [characters],
        appsSection: [disabled],
        startupSection: [launchAtLogin],
    ]

    /// Parses `text` and validates it against the schema.
    ///
    /// A key the file omits keeps its default rather than failing: the app has to run
    /// against a file a user trimmed, and the defaults are documented in the file the
    /// app itself wrote. An unknown key is still an error — it is almost always a typo
    /// for a real one, and silently ignoring it is how a setting appears not to work.
    public static func config(from text: String) throws(ConfigError) -> HintjumpConfig {
        try config(from: TOMLSubset.parse(text))
    }

    /// Validates an already-parsed document.
    public static func config(from document: TOMLDocument) throws(ConfigError) -> HintjumpConfig {
        try rejectUnknownNames(in: document)
        var config = HintjumpConfig.builtIn
        config.clickInWindow = try trigger(clickInWindow, in: document) ?? config.clickInWindow
        config.rightClickInWindow = try trigger(rightClickInWindow, in: document)
            ?? config.rightClickInWindow
        config.appMenus = try trigger(appMenus, in: document) ?? config.appMenus
        config.statusIcons = try trigger(statusIcons, in: document) ?? config.statusIcons
        if let entry = document.table(hintsSection)?.entry(characters) {
            config.hintCharacters = try hintCharacters(from: entry)
        }
        if let entry = document.table(appsSection)?.entry(disabled) {
            config.disabledApps = try strings(from: entry)
        }
        if let entry = document.table(startupSection)?.entry(launchAtLogin) {
            config.launchAtLogin = try boolean(from: entry)
        }
        try rejectRepeatedTriggers(in: config, document: document)
        return config
    }

    // MARK: - Names

    private static func rejectUnknownNames(in document: TOMLDocument) throws(ConfigError) {
        for table in document.tables {
            guard let known = keys[table.name] else {
                throw ConfigError(line: table.line, reason: "unknown section `[\(table.name)]`")
            }
            for entry in table.entries where !known.contains(entry.key) {
                throw ConfigError(line: entry.line, reason: "unknown key `\(entry.key)`")
            }
        }
    }

    // MARK: - Values

    private static func trigger(
        _ key: String,
        in document: TOMLDocument,
    ) throws(ConfigError) -> KeyCombination? {
        guard let entry = document.table(triggersSection)?.entry(key) else {
            return nil
        }
        let text = try string(from: entry)
        do {
            return try KeyCombination.parse(text)
        } catch {
            throw ConfigError(line: entry.line, reason: error.reason)
        }
    }

    private static func hintCharacters(from entry: TOMLEntry) throws(ConfigError) -> [Character] {
        let text = try string(from: entry)
        var seen: Set<Character> = []
        for character in text {
            guard character.isASCII, character.isLetter, character.isLowercase else {
                throw ConfigError(
                    line: entry.line,
                    reason: "`\(character)` is not a hint character — use lower-case ASCII letters",
                )
            }
            guard seen.insert(character).inserted else {
                throw ConfigError(
                    line: entry.line,
                    reason: "the hint character `\(character)` is repeated",
                )
            }
        }
        guard text.count >= minimumHintCharacters else {
            throw ConfigError(
                line: entry.line,
                reason: "hints need at least \(minimumHintCharacters) characters, and this has \(text.count)",
            )
        }
        return Array(text)
    }

    private static func rejectRepeatedTriggers(
        in config: HintjumpConfig,
        document: TOMLDocument,
    ) throws(ConfigError) {
        var seen: [KeyCombination: String] = [:]
        for (key, combination) in config.triggers {
            if let owner = seen[combination] {
                let line = document.table(triggersSection)?.entry(key)?.line
                    ?? document.table(triggersSection)?.line ?? 1
                throw ConfigError(
                    line: line,
                    reason: "`\(key)` uses the same combination as `\(owner)` — every trigger needs its own",
                )
            }
            seen[combination] = key
        }
    }

    // MARK: - Types

    private static func string(from entry: TOMLEntry) throws(ConfigError) -> String {
        guard case let .string(value) = entry.value else { throw typeError(
            entry,
            expected: "a string",
        ) }
        return value
    }

    private static func strings(from entry: TOMLEntry) throws(ConfigError) -> [String] {
        guard case let .stringArray(values) = entry.value else {
            throw typeError(entry, expected: "an array of strings")
        }
        return values
    }

    private static func boolean(from entry: TOMLEntry) throws(ConfigError) -> Bool {
        guard case let .boolean(value) = entry.value else {
            throw typeError(entry, expected: "true or false")
        }
        return value
    }

    private static func typeError(_ entry: TOMLEntry, expected: String) -> ConfigError {
        ConfigError(
            line: entry.line,
            reason: "`\(entry.key)` needs \(expected), not \(entry.value.kindName)",
        )
    }
}
