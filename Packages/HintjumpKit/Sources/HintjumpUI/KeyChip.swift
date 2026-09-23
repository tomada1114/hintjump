import SwiftUI

/// A key combination drawn as a keycap, e.g. `⌃⇧Space` — one of the three things the
/// Settings window draws for itself (`docs/design/settings-window.md` › Controls).
///
/// It draws the text Core formatted (``HintjumpCore/KeyCombination/displayText``) and
/// nothing else, so Getting Started and the Shortcuts pane (#104) show a combination the
/// same way.
struct KeyChip: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(SettingsPalette.chipFont)
            .padding(.horizontal, SettingsPalette.chipHorizontalPadding)
            .padding(.vertical, SettingsPalette.chipVerticalPadding)
            .background {
                RoundedRectangle(cornerRadius: SettingsPalette.chipCornerRadius)
                    .fill(.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: SettingsPalette.chipCornerRadius)
                            .strokeBorder(.tertiary, lineWidth: SettingsPalette.chipOutlineWidth)
                    }
            }
    }
}
