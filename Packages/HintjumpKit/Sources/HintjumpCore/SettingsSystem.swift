import Foundation

/// The ports the Settings window's buttons reach the OS through.
///
/// Grouped so ``SettingsViewModel`` takes one value for them, and so a pane added later
/// — the Apps pane's app picker (#106), General's login-item settings (#105) — adds its
/// port here rather than another initializer parameter.
public struct SettingsPorts: Sendable {
    /// Getting Started's "Open System Settings".
    public let systemSettings: any SystemSettingsOpening
    /// Config File's "Open" and "Reveal in Finder".
    public let configFile: any ConfigFileOpening
    /// Config File's "Copy Path".
    public let pasteboard: any PasteboardWriting

    public init(
        systemSettings: any SystemSettingsOpening,
        configFile: any ConfigFileOpening,
        pasteboard: any PasteboardWriting,
    ) {
        self.systemSettings = systemSettings
        self.configFile = configFile
        self.pasteboard = pasteboard
    }
}

/// The app's version and build, as About shows them.
public struct AppVersion: Equatable, Sendable {
    /// What a missing or malformed value reads as — visible, rather than an empty line.
    static let unknown = "unknown"

    /// `CFBundleShortVersionString`, e.g. `0.1.0`.
    public let version: String
    /// `CFBundleVersion`, e.g. `1`.
    public let build: String

    public init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    /// Reads the two keys from a bundle's info dictionary — `Bundle.main.infoDictionary`
    /// in the app — so the fallback for a missing key is decided here, where a test sees
    /// it, rather than in `App/`.
    public init(infoDictionary: [String: Any]) {
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? Self.unknown
        build = infoDictionary["CFBundleVersion"] as? String ?? Self.unknown
    }
}

/// Everything the Settings window takes from the system around it rather than from the
/// configuration: the ports its buttons use, the app's version, the home folder the
/// config path is shown relative to, and how a time of day is written.
public struct SettingsSystem: Sendable {
    /// The user's short time style, e.g. "10:42" — what "Loaded at <time>" shows.
    public static let shortTime: @Sendable (Date) -> String = { date in
        date.formatted(date: .omitted, time: .shortened)
    }

    public let ports: SettingsPorts
    public let version: AppVersion
    /// The home folder, shown as `~` at the start of the config path.
    public let homeDirectory: String
    /// Writes the time of day a load happened at.
    public let formatTime: @Sendable (Date) -> String

    /// `formatTime` is a parameter so a test pins what the user's locale would otherwise
    /// decide; the app takes ``shortTime``.
    public init(
        ports: SettingsPorts,
        version: AppVersion,
        homeDirectory: String,
        formatTime: @escaping @Sendable (Date) -> String = Self.shortTime,
    ) {
        self.ports = ports
        self.version = version
        self.homeDirectory = homeDirectory
        self.formatTime = formatTime
    }
}
