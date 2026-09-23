extension KeyCombination {
    /// The combination drawn the way macOS menus draw one — modifiers in the order
    /// ⌃ ⌥ ⇧ ⌘, then the key — which is what a key chip in the Settings window shows
    /// (`docs/design/settings-window.md` › Controls). The default click-in-window
    /// trigger reads `⌃⇧Space`.
    ///
    /// A Core formatter rather than a view's, so the Getting Started rows here and the
    /// Shortcuts pane's recorder (#104) cannot draw the same trigger two ways.
    public var displayText: String {
        modifiers.sorted().map(Self.symbol(for:)).joined() + Self.displayText(for: key)
    }

    /// The symbol a macOS menu draws for `modifier`: ⌃ ⌥ ⇧ ⌘.
    static func symbol(for modifier: KeyModifier) -> String {
        switch modifier {
        case .command:
            "⌘"

        case .control:
            "⌃"

        case .option:
            "⌥"

        case .shift:
            "⇧"
        }
    }

    /// `key` as a macOS menu names it: a letter in upper case, a digit, `Space`,
    /// `Return`, `Tab`, `F1`–`F12`, or the punctuation character itself.
    ///
    /// Capitalizing the file's lower-case name covers every case at once — `f12` becomes
    /// `F12`, `space` becomes `Space`, and a digit or a punctuation character has no
    /// upper case to change to.
    static func displayText(for key: KeyName) -> String {
        key.rawValue.prefix(1).uppercased() + key.rawValue.dropFirst()
    }
}
