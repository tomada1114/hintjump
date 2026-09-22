/// The defaults, and the file that spells them.
///
/// ``defaultFileContents`` is the single source of truth: ``HintjumpConfig/default`` is
/// parsed from it rather than written twice, so the file the app drops on a fresh
/// machine and the values it runs with cannot drift apart. A test asserts the round
/// trip, and the force-free fallback below is what a parse failure would degrade to —
/// unreachable while that test passes, and never a `try!`
/// (`.claude/rules/swift.md` › Error Handling).
extension HintjumpConfig {
    /// The commented file written once when `~/.config/hintjump/config.toml` is absent.
    public static let defaultFileContents = """
    # Hintjump configuration. Edit, then choose "Reload Config" from the status menu.

    [triggers]
    # Modifiers: ctrl, alt, shift, cmd. Keys: a letter, a digit, space, return, tab,
    # f1-f12, or one of - = [ ] \\ ; ' , . / `. Every trigger needs at least one modifier.
    click_in_window = "ctrl+shift+space"
    right_click_in_window = "ctrl+alt+shift+space"
    app_menus = "ctrl+shift+m"
    status_icons = "ctrl+shift+s"

    [hints]
    # Letters used for hints, most preferred first. Letters only, each once.
    characters = "asdfghjklqwertyuiopzxcvbnm"

    [apps]
    # Bundle identifiers of apps where Hintjump stays off. "Disable in <App>" edits this list.
    disabled = []

    [startup]
    launch_at_login = false

    """

    /// The values ``defaultFileContents`` parses to.
    public static let `default`: HintjumpConfig = (try? ConfigSchema
        .config(from: defaultFileContents))
        ?? builtIn

    /// What ``default`` would be if its own file failed to parse — the same values,
    /// hand-built from combinations that cannot fail to construct.
    ///
    /// It is also the base a partial file is read against: a key the user's file omits
    /// keeps this value. ``default`` cannot serve as that base, because parsing is how
    /// ``default`` itself is built.
    static let builtIn = HintjumpConfig(
        clickInWindow: KeyCombination(modifiers: [.control, .shift], key: .space),
        rightClickInWindow: KeyCombination(modifiers: [.control, .option, .shift], key: .space),
        appMenus: KeyCombination(modifiers: [.control, .shift], key: .letterM),
        statusIcons: KeyCombination(modifiers: [.control, .shift], key: .letterS),
        hintCharacters: Array("asdfghjklqwertyuiopzxcvbnm"),
        disabledApps: [],
        launchAtLogin: false,
    )
}
