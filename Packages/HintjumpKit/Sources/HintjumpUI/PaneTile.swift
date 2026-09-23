import SwiftUI

/// A sidebar row's icon: the pane's SF Symbol in white on a rounded square drawn as a
/// hint tag — System Settings' icon tiles, in the overlay's ink
/// (`docs/design/settings-window.md` › Icon tiles).
///
/// The fill is the only thing that changes: the accent while the pane needs the user,
/// the ink otherwise. Which one is Core's answer (`SettingsViewModel.needsAttention`);
/// the tile only draws it. It is decoration for VoiceOver, which reads the row's title
/// and its "Needs attention" value instead.
struct PaneTile: View {
    let symbolName: String
    let needsAttention: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: SettingsPalette.tileCornerRadius)
            .fill(needsAttention ? SettingsPalette.attention : SettingsPalette.tile)
            .frame(width: SettingsPalette.tileSide, height: SettingsPalette.tileSide)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: SettingsPalette.glyphSize))
                    .foregroundStyle(SettingsPalette.glyph)
            }
            .accessibilityHidden(true)
    }
}
