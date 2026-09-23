import HintjumpCore
import SwiftUI

/// One sidebar row: the pane's tile and its name.
///
/// While the tile has the accent, the row's accessibility value says "Needs attention",
/// so the attention is never carried by color alone.
struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let model: SettingsViewModel

    var body: some View {
        Label {
            Text(pane.title)
        } icon: {
            PaneTile(symbolName: pane.symbolName, needsAttention: model.needsAttention(pane))
        }
        .accessibilityValue(model.accessibilityValue(for: pane) ?? "")
    }
}
