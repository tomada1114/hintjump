import HintjumpCore
import SwiftUI

/// The detail column: the selected pane's grouped form.
struct SettingsDetail: View {
    let model: SettingsViewModel

    var body: some View {
        switch model.selection {
        case .about:
            AboutPane(model: model)

        case .configFile:
            ConfigFilePane(model: model)

        case .gettingStarted:
            GettingStartedPane(model: model)
        }
    }
}
