import Foundation

/// The Config File and About panes' facts, read from the store and the system each time
/// they are drawn.
extension SettingsViewModel {
    /// Where the repository is; About's link.
    static let repositoryAddress = "https://github.com/tomada1114/hintjump"

    /// The config file's path with the home folder written as `~`, as the pane shows it.
    public var configPath: String {
        Self.abbreviatingHome(in: store.path, home: system.homeDirectory)
    }

    /// When the last load or reload happened, whatever it found, or `nil` before one.
    public var lastLoadDate: Date? {
        store.lastLoad?.date
    }

    /// Why the last load failed, or `nil` when it succeeded or has not happened.
    public var lastLoadError: ConfigError? {
        guard case let .failure(error) = store.lastLoad?.result else {
            return nil
        }
        return error
    }

    /// The last load's result as the pane reads it: "Loaded at 10:42", or the error's
    /// "Line 12: unknown key `hotkey_left`" — `nil` before the first load.
    public var lastLoadLine: String? {
        guard let record = store.lastLoad else {
            return nil
        }
        switch record.result {
        case .success:
            return "Loaded at \(system.formatTime(record.date))"

        case let .failure(error):
            return error.message
        }
    }

    /// The line under a failed load, or `nil`: the store keeps the last good settings in
    /// force, and the user should know the broken file changed nothing yet.
    public var lastLoadNote: String? {
        lastLoadError == nil ? nil : "Hintjump keeps using the last settings that loaded."
    }

    /// Whether to offer "Create Default File": only while the file is missing.
    public var canCreateDefaultFile: Bool {
        fileState == .missing
    }

    /// What to say about a file that is there but cannot be read, or `nil`.
    public var fileNotice: String? {
        fileState == .unreadable ? "Hintjump couldn't read this file." : nil
    }

    /// About's version line, e.g. "Version 0.1.0 (1)".
    public var versionLine: String {
        "Version \(system.version.version) (\(system.version.build))"
    }

    /// The repository link's text: the address without its scheme.
    public var repositoryTitle: String {
        "github.com/tomada1114/hintjump"
    }

    /// The repository link's destination.
    public var repositoryURL: URL? {
        URL(string: Self.repositoryAddress)
    }

    /// `path` with a leading `home` folder written as `~`.
    ///
    /// Only a whole leading folder counts — `/Users/ann` does not shorten
    /// `/Users/anna/…` — and an empty `home` shortens nothing.
    static func abbreviatingHome(in path: String, home: String) -> String {
        let trimmedHome = home.hasSuffix("/") ? String(home.dropLast()) : home
        guard !trimmedHome.isEmpty else {
            return path
        }
        if path == trimmedHome {
            return "~"
        }
        guard path.hasPrefix(trimmedHome + "/") else {
            return path
        }
        return "~" + path.dropFirst(trimmedHome.count)
    }
}
