/// The Settings window's fixed strings, exactly as `docs/design/settings-window.md` ›
/// Copy words them. A string that depends on state — a status, a load result, a
/// shortcut line — is Core's (``HintjumpCore/SettingsViewModel``); these never change.
enum SettingsCopy {
    /// The window's title.
    static let windowTitle = "Hintjump Settings"

    // MARK: Getting Started

    static let allowAccessibilityHeader = "Allow Accessibility"
    static let allowAccessibilityExplanation = """
    Hintjump reads the buttons, links, and menus on screen, and clicks the one whose \
    label you type. macOS allows that only for apps you give Accessibility access.
    """
    static let openSystemSettings = "Open System Settings"
    static let tryItHeader = "Try it"
    static let collisionHeader = "Turn it off where a shortcut collides"
    static let collisionExplanation = """
    If an app uses one of these shortcuts itself, turn Hintjump off in that app and the \
    app gets the key back. You can also choose "Disable in" from the status menu while \
    that app is in front.
    """

    // MARK: Config File

    static let configFileExplanation = """
    Every setting in this window is saved to this file, which you can also edit by hand, \
    share, and diff.
    """
    static let open = "Open"
    static let revealInFinder = "Reveal in Finder"
    static let copyPath = "Copy Path"
    static let createDefaultFile = "Create Default File"

    // MARK: About

    static let appName = "Hintjump"
    static let license = "MIT License"
    static let privacy = "Hintjump sends no analytics."
}
