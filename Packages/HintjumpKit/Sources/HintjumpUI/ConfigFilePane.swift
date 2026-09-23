import HintjumpCore
import SwiftUI

/// The file every setting is saved to, the ways into it, and what its last load said
/// (`docs/design/settings-window.md` › Config File).
struct ConfigFilePane: View {
    let model: SettingsViewModel

    var body: some View {
        Form {
            fileSection
            lastLoadSection
        }
        .formStyle(.grouped)
    }

    /// The explanation, the path, and the buttons that hand the file to another app.
    private var fileSection: some View {
        Section {
            Text(SettingsCopy.configFileExplanation)
            Text(model.configPath)
                .font(.body.monospaced())
                .textSelection(.enabled)
            HStack {
                Button(SettingsCopy.open) {
                    model.openConfigFile()
                }
                Button(SettingsCopy.revealInFinder) {
                    model.revealConfigFile()
                }
                Button(SettingsCopy.copyPath) {
                    model.copyConfigPath()
                }
            }
        } header: {
            PaneHeading(pane: .configFile, sectionHeader: nil)
        }
    }

    /// What the last load said, and what can be done about a missing or unreadable file.
    private var lastLoadSection: some View {
        Section {
            if let line = model.lastLoadLine {
                // Selectable, so the error's line and reason can be copied into a search
                // or an issue.
                Text(line)
                    .textSelection(.enabled)
            }
            if let note = model.lastLoadNote {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            if let notice = model.fileNotice {
                Text(notice)
            }
            if model.canCreateDefaultFile {
                Button(SettingsCopy.createDefaultFile) {
                    model.createDefaultFile()
                }
            }
        }
    }
}
