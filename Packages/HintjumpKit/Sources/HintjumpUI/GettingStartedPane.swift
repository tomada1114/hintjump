import HintjumpCore
import SwiftUI

/// One "Try it" line: the lead-in, the combination as a key chip, and what it does.
/// VoiceOver reads the whole line as one sentence.
private struct ShortcutLineView: View {
    let line: ShortcutLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(line.lead)
            KeyChip(keys: line.keys)
                .padding(.leading, SettingsPalette.chipLeadingGap)
            Text(line.rest)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.sentence)
    }
}

/// The first-run guide: the Accessibility grant, the four shortcuts to try, and how to
/// turn Hintjump off where a shortcut collides (`docs/design/settings-window.md` ›
/// Getting Started).
struct GettingStartedPane: View {
    let model: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text(SettingsCopy.allowAccessibilityExplanation)
                HStack {
                    Text(model.accessibilityStatus)
                        .fontWeight(.medium)
                    Spacer()
                    Button(SettingsCopy.openSystemSettings) {
                        model.openAccessibilitySettings()
                    }
                }
            } header: {
                PaneHeading(
                    pane: .gettingStarted,
                    sectionHeader: SettingsCopy.allowAccessibilityHeader,
                )
            }
            Section(SettingsCopy.tryItHeader) {
                if let notice = model.tryItNotice {
                    Text(notice)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.shortcutLines) { line in
                    ShortcutLineView(line: line)
                }
            }
            // "Choose Apps…", the link to the Apps pane, joins this section with #106.
            Section(SettingsCopy.collisionHeader) {
                Text(SettingsCopy.collisionExplanation)
            }
        }
        .formStyle(.grouped)
    }
}
