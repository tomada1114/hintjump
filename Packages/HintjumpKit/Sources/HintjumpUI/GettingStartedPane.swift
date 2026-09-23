import HintjumpCore
import SwiftUI

/// One "Try it" line: the lead-in, the combination as a key chip, and what it does, as
/// one paragraph that wraps like any other (see ``KeyChip/inlineImage(keys:colorScheme:)``).
/// VoiceOver reads the whole line as one sentence.
private struct ShortcutLineView: View {
    let line: ShortcutLine
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        Text("\(line.lead) \(chip)\(line.rest)")
            .accessibilityLabel(line.sentence)
    }

    /// The chip inline, its text on the line's baseline; the keys as plain text only if
    /// the chip could not be drawn.
    private var chip: Text {
        guard let image = KeyChip.inlineImage(keys: line.keys, colorScheme: colorScheme) else {
            return Text(line.keys)
        }
        return Text(image).baselineOffset(KeyChip.inlineBaselineOffset)
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
