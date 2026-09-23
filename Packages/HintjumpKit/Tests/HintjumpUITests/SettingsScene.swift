import Foundation
import HintjumpCore
import Testing

/// The window's model in a scene's state, built the way `App/` builds it — a real
/// ``ConfigStore``, ``ConfigApplier``, and ``AccessibilityGateViewModel`` — over
/// stand-ins for the OS that answer from data.
@MainActor
enum SettingsSceneModel {
    /// A home folder and a config path under it, so the pane shows the `~` form.
    static let home = "/Users/someone"
    static let path = "/Users/someone/.config/hintjump/config.toml"

    /// A file whose second line is a key the schema does not know, so the load fails
    /// with a line-numbered reason.
    static let brokenFile = "[hints]\nhotkey_left = \"asdf\"\n"

    static func model(for scene: SettingsScene) -> SettingsViewModel {
        let file = StandInConfigFile(
            path: path,
            contents: scene.needsAttention ? brokenFile : HintjumpConfig.defaultFileContents,
        )
        let store = ConfigStore(file: file, loginItem: StandInLoginItem()) {
            Date(timeIntervalSince1970: 0)
        }
        let controller = TriggerController(registrar: StandInRegistrar())
        let policy = DisabledAppsPolicy(controller: controller, observer: StandInObserver()) {
            store.config
        }
        let gate = AccessibilityGateViewModel(trust: StandInTrust(isTrusted: !scene.needsAttention))
        let ports = SettingsPorts(
            systemSettings: StandInSystemSettings(),
            configFile: StandInOpener(),
            pasteboard: StandInPasteboard(),
        )
        let model = SettingsViewModel(
            store: store,
            applier: ConfigApplier(store: store, controller: controller, policy: policy),
            gate: gate,
            system: SettingsSystem(
                ports: ports,
                version: AppVersion(version: "0.1.0", build: "1"),
                homeDirectory: home,
            ) { _ in "10:42" },
        )
        _ = try? store.load()
        model.refresh()
        model.select(scene.pane)
        return model
    }
}

// MARK: - Stand-ins for the OS

/// A config file held in memory.
private final class StandInConfigFile: ConfigFileAccessing, @unchecked Sendable {
    // `@unchecked Sendable` is sound: every instance is created, read, and written on the
    // main actor its store runs on, inside one test.
    let path: String
    private var contents: String?

    init(path: String, contents: String?) {
        self.path = path
        self.contents = contents
    }

    func read() -> String? {
        contents
    }

    func write(_ text: String) {
        contents = text
    }
}

@MainActor
private final class StandInLoginItem: LoginItemRegistering {
    private(set) var isRegistered = false

    func setRegistered(_ enabled: Bool) {
        isRegistered = enabled
    }
}

@MainActor
private final class StandInRegistrar: TriggerRegistering {
    private var onPress: (@MainActor (EntryPoint) -> Void)?

    func register(
        _: [TriggerBinding],
        onPress: @escaping @MainActor (EntryPoint) -> Void,
    ) -> [TriggerRegistrationFailure] {
        // Held like a real registrar holds it; nothing is ever pressed.
        self.onPress = onPress
        return []
    }

    func unregisterAll() {
        onPress = nil
    }
}

@MainActor
private final class StandInObserver: FrontmostAppObserving {
    private var handler: (@MainActor (FrontmostApp) -> Void)?

    func startObserving(_ handler: @escaping @MainActor (FrontmostApp) -> Void) {
        // Held like a real observer holds it; no app ever switches.
        self.handler = handler
    }

    func stopObserving() {
        handler = nil
    }
}

@MainActor
private final class StandInTrust: AccessibilityTrustChecking {
    let isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestTrust() {
        // A rendering test never prompts.
    }
}

@MainActor
private final class StandInSystemSettings: SystemSettingsOpening {
    func openAccessibilitySettings() {
        // No button is pressed in a rendering test.
    }
}

@MainActor
private final class StandInOpener: ConfigFileOpening {
    func open(path _: String) {
        // No button is pressed in a rendering test.
    }

    func reveal(path _: String) {
        // No button is pressed in a rendering test.
    }
}

@MainActor
private final class StandInPasteboard: PasteboardWriting {
    func copy(_: String) {
        // No button is pressed in a rendering test.
    }
}

/// One Settings window state worth a reference image: the pane it shows, the appearance
/// it is drawn in, and whether the panes that can need the user do.
struct SettingsScene: CustomTestStringConvertible {
    enum Appearance: String, CaseIterable {
        case light
        case dark
    }

    /// Every pane, in both appearances, with the attention tiles on and off.
    static let all: [Self] = SettingsPane.allCases.flatMap { pane in
        Appearance.allCases.flatMap { appearance in
            [true, false].map { Self(pane: pane, appearance: appearance, needsAttention: $0) }
        }
    }

    let pane: SettingsPane
    let appearance: Appearance
    /// Accessibility not granted and a config file that failed to load, so both
    /// Getting Started's and Config File's tiles take the accent — or neither.
    let needsAttention: Bool

    /// The reference image's file name, without the extension, e.g.
    /// `settings-config-file-dark-attention`.
    var name: String {
        let paneName = switch pane {
        case .about:
            "about"

        case .configFile:
            "config-file"

        case .gettingStarted:
            "getting-started"
        }
        return "settings-\(paneName)-\(appearance.rawValue)-\(needsAttention ? "attention" : "clear")"
    }

    var testDescription: String {
        name
    }
}
