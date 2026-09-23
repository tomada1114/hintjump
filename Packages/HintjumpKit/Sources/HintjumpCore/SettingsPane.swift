/// A pane of the Settings window, one sidebar row each
/// (`docs/design/settings-window.md` › Sidebar).
///
/// A pane is added here only by the issue that builds it, so the sidebar never shows an
/// empty pane: Shortcuts (#104), Hints and General (#105), and Apps (#106) each add a
/// case and take their place in ``allCases``, and nothing else in the window changes to
/// make room for them.
public enum SettingsPane: String, CaseIterable, Identifiable, Sendable {
    /// The version, license, repository, and privacy line.
    case about
    /// The file every setting is saved to, and what its last load said.
    case configFile
    /// The first-run guide: the Accessibility grant and the four shortcuts to try.
    case gettingStarted

    /// The panes in sidebar order, rather than the declaration order SwiftLint's
    /// `sorted_enum_cases` keeps alphabetical. The spec's full order is Getting Started,
    /// Shortcuts, Hints, Apps, General, Config File, About.
    public static let allCases: [Self] = [
        .gettingStarted,
        .configFile,
        .about,
    ]

    public var id: Self {
        self
    }

    /// The sidebar row's name, which is also the detail pane's heading.
    public var title: String {
        switch self {
        case .about:
            "About"

        case .configFile:
            "Config File"

        case .gettingStarted:
            "Getting Started"
        }
    }

    /// The SF Symbol drawn in the pane's icon tile.
    public var symbolName: String {
        switch self {
        case .about:
            "info.circle"

        case .configFile:
            "doc.text"

        case .gettingStarted:
            "hand.wave"
        }
    }
}
