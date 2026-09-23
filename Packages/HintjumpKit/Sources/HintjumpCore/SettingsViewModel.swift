import Observation

/// The Settings window's state and actions: which pane shows, which sidebar tiles need
/// the user, and what each pane says (`docs/design/settings-window.md`).
///
/// One view model for the whole window rather than one per pane, because the sidebar
/// needs every pane's attention flag at once, and a pane added later (#104, #105, #106)
/// reads the same store and applier. What each pane shows lives here, where the
/// coverage floor sees it; the views in `HintjumpUI` only draw it. The Config File and
/// About facts are in `SettingsViewModel+ConfigFile.swift`.
///
/// Everything it reads is observable — the store, the gate, its own selection — so an
/// open window follows a reload from the status menu or a grant given in System
/// Settings without being told.
@MainActor
@Observable
public final class SettingsViewModel {
    /// What a sidebar row's accessibility value says while its tile has the accent, so
    /// the attention is never carried by color alone.
    public static let needsAttentionValue = "Needs attention"

    /// The pane the detail shows. Remembered for as long as the app runs, not across
    /// launches: the first open after launch shows Getting Started.
    public private(set) var selection: SettingsPane = .gettingStarted

    /// What the last ``refresh()`` found the config file to be, or `nil` before one.
    public private(set) var fileState: ConfigFileState?

    let store: ConfigStore
    let system: SettingsSystem
    private let applier: ConfigApplier
    private let gate: AccessibilityGateViewModel

    /// The panes the sidebar lists, in order.
    public var panes: [SettingsPane] {
        SettingsPane.allCases
    }

    /// Whether this process holds the Accessibility grant, as far as the gate last knew.
    public var isAccessibilityAllowed: Bool {
        gate.state == .ready
    }

    /// Getting Started's status line under "Allow Accessibility".
    public var accessibilityStatus: String {
        isAccessibilityAllowed ? "Allowed" : "Not allowed yet"
    }

    /// The line "Try it" leads with while the shortcuts cannot work yet, or `nil`.
    public var tryItNotice: String? {
        isAccessibilityAllowed ? nil : "Allow Accessibility first, then try the shortcuts here."
    }

    /// The four triggers, in file order, each with its current combination.
    public var shortcutLines: [ShortcutLine] {
        let config = store.config
        return EntryPoint.allCases.map { entryPoint in
            ShortcutLine(entryPoint: entryPoint, combination: config.combination(for: entryPoint))
        }
    }

    /// Takes the same store, applier, and gate `App/` starts with, so the window shows
    /// the configuration in force and the grant the status item's gate last checked.
    public init(
        store: ConfigStore,
        applier: ConfigApplier,
        gate: AccessibilityGateViewModel,
        system: SettingsSystem,
    ) {
        self.store = store
        self.applier = applier
        self.gate = gate
        self.system = system
    }

    /// Shows `pane`. `nil` — a list's "nothing selected", after a click between rows —
    /// keeps the pane that was showing rather than leaving the detail empty.
    public func select(_ pane: SettingsPane?) {
        guard let pane, pane != selection else {
            return
        }
        selection = pane
        AppLog.settings.debug("pane: \(pane.rawValue, privacy: .public)")
    }

    /// Whether `pane`'s tile takes the accent: Getting Started while Accessibility is not
    /// granted (or not yet checked), Config File while the last load failed.
    public func needsAttention(_ pane: SettingsPane) -> Bool {
        switch pane {
        case .about:
            false

        case .configFile:
            lastLoadError != nil

        case .gettingStarted:
            !isAccessibilityAllowed
        }
    }

    /// The sidebar row's accessibility value: ``needsAttentionValue`` while the tile has
    /// the accent, and nothing otherwise.
    public func accessibilityValue(for pane: SettingsPane) -> String? {
        needsAttention(pane) ? Self.needsAttentionValue : nil
    }

    /// Asks again what the window cannot be told: whether the grant is held — macOS
    /// reports a grant through no callback — and whether the config file is there.
    ///
    /// Call when the window appears and whenever the app becomes active, which is how
    /// the user comes back from System Settings or from deleting the file.
    public func refresh() {
        gate.refresh()
        let state = store.fileState()
        fileState = state
        let pane = selection.rawValue
        let grant = isAccessibilityAllowed ? "allowed" : "not-allowed"
        AppLog.settings.info(
            """
            settings refreshed: pane=\(pane, privacy: .public) \
            accessibility=\(grant, privacy: .public) \
            file=\(String(describing: state), privacy: .public)
            """,
        )
    }

    /// "Open System Settings": the Privacy & Security › Accessibility pane.
    public func openAccessibilitySettings() {
        system.ports.systemSettings.openAccessibilitySettings()
    }

    /// "Open": the config file in the user's editor.
    public func openConfigFile() {
        system.ports.configFile.open(path: store.path)
    }

    /// "Reveal in Finder": the config file, selected in Finder.
    public func revealConfigFile() {
        system.ports.configFile.reveal(path: store.path)
    }

    /// "Copy Path": the full path, not the `~` form the pane shows, so it pastes the
    /// same into a terminal, a script, or Finder's "Go to Folder".
    public func copyConfigPath() {
        system.ports.pasteboard.copy(store.path)
    }

    /// "Create Default File": writes the commented default and puts it in force.
    ///
    /// The file is the source of truth, so once it holds the default the default is what
    /// applies: this is a ``ConfigStore/load()`` — which writes the default when the
    /// file is missing — followed by ``ConfigApplier/apply()``, the one apply path. A
    /// failed load is logged by the store and applies nothing; the file is looked at
    /// again either way, so the button goes away only once the file is really there.
    public func createDefaultFile() {
        let loaded = (try? store.load()) != nil
        if loaded {
            applier.apply()
            AppLog.settings.info("default config file created and applied")
        }
        fileState = store.fileState()
    }
}
