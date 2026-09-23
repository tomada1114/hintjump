import HintjumpCore
import SwiftUI

/// The version, license, repository, and privacy line
/// (`docs/design/settings-window.md` › About).
struct AboutPane: View {
    let model: SettingsViewModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text(SettingsCopy.appName)
                        .font(.headline)
                    Text(model.versionLine)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text(SettingsCopy.license)
                if let url = model.repositoryURL {
                    Link(model.repositoryTitle, destination: url)
                }
                Text(SettingsCopy.privacy)
            } header: {
                PaneHeading(pane: .about, sectionHeader: nil)
            }
        }
        .formStyle(.grouped)
    }
}
