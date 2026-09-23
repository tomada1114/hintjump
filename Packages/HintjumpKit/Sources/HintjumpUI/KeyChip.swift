import AppKit
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

extension KeyChip {
    /// How far below the line's baseline an inline chip's bottom edge sits: its bottom
    /// padding plus its font's descent, so the chip's own text shares the line's baseline.
    static var inlineBaselineOffset: CGFloat {
        let font = NSFont.systemFont(ofSize: SettingsPalette.chipFontSize, weight: .medium)
        return font.descender - SettingsPalette.chipVerticalPadding
    }

    /// The chip drawn as an image, to sit inside a line of text.
    ///
    /// Inline rather than beside the text in a stack, so a line that wraps — Getting
    /// Started's right-click line does at the window's minimum width — is one paragraph
    /// laid out by the text system alone. A wrapped `Text` baseline-aligned beside a chip
    /// in an `HStack` was placed differently by the CI runner's macOS than by a
    /// developer's, while a lone paragraph lays out the same on both. The scale is fixed
    /// rather than the display's, so the image does not depend on the screen that draws
    /// it; `nil` only if the renderer draws nothing.
    @MainActor
    static func inlineImage(keys: String, colorScheme: ColorScheme) -> Image? {
        let renderer = ImageRenderer(
            content: KeyChip(keys: keys).environment(\.colorScheme, colorScheme),
        )
        renderer.scale = SettingsPalette.chipImageScale
        return renderer.nsImage.map { Image(nsImage: $0) }
    }
}
