/// Everything the configuration file says, as a value.
///
/// The four triggers are separate stored properties rather than a dictionary keyed by
/// an enum: each one is a distinct entry point with its own consumer, and a missing
/// key in a dictionary would be a runtime surprise where a stored property cannot be.
public struct HintjumpConfig: Equatable, Sendable {
    /// `[triggers] click_in_window`.
    public var clickInWindow: KeyCombination
    /// `[triggers] right_click_in_window`.
    public var rightClickInWindow: KeyCombination
    /// `[triggers] app_menus`.
    public var appMenus: KeyCombination
    /// `[triggers] status_icons`.
    public var statusIcons: KeyCombination
    /// `[hints] characters`, most preferred first.
    public var hintCharacters: [Character]
    /// `[apps] disabled`: bundle identifiers where Hintjump stays off.
    public var disabledApps: [String]
    /// `[startup] launch_at_login`. ``ConfigStore`` applies it after every successful
    /// load, through ``LoginItemRegistering``.
    public var launchAtLogin: Bool

    /// The four triggers with the key each is written under, in file order — what the
    /// "two triggers share a combination" check walks.
    public var triggers: [(key: String, combination: KeyCombination)] {
        [
            (ConfigSchema.clickInWindow, clickInWindow),
            (ConfigSchema.rightClickInWindow, rightClickInWindow),
            (ConfigSchema.appMenus, appMenus),
            (ConfigSchema.statusIcons, statusIcons),
        ]
    }

    public init(
        clickInWindow: KeyCombination,
        rightClickInWindow: KeyCombination,
        appMenus: KeyCombination,
        statusIcons: KeyCombination,
        hintCharacters: [Character],
        disabledApps: [String],
        launchAtLogin: Bool,
    ) {
        self.clickInWindow = clickInWindow
        self.rightClickInWindow = rightClickInWindow
        self.appMenus = appMenus
        self.statusIcons = statusIcons
        self.hintCharacters = hintCharacters
        self.disabledApps = disabledApps
        self.launchAtLogin = launchAtLogin
    }
}
