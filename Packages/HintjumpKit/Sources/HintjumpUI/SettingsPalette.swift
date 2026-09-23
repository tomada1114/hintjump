import SwiftUI

/// The colors and sizes the Settings window draws for itself — its sidebar tiles and
/// key chips (`docs/design/settings-window.md` › Icon tiles, Controls). Everything else
/// in the window is a system control in the system accent color.
enum SettingsPalette {
    private static let attentionRGB: UInt32 = 0xE5470F

    /// The red-orange accent, `#E5470F`: a tile's fill only while its pane needs the
    /// user. It keeps the role it had in the overlay before #113 — "this is the one to
    /// act on" — so it is never a decoration, a control's tint, or a selection mark.
    static let attention = Palette.color(attentionRGB)
    /// A tile's normal fill: the overlay's near-black ink, `#1C1C1E`.
    static let tile = Palette.ink
    /// A tile's glyph, white on either fill.
    static let glyph = Color.white

    /// A tile's side, in points.
    static let tileSide: CGFloat = 20
    /// A tile's corner radius: the overlay tag's own, so a tile reads as a hint tag.
    static let tileCornerRadius = Palette.cornerRadius
    /// The glyph's point size inside a tile.
    static let glyphSize: CGFloat = 12

    /// A key chip's type, corner radius, padding, and outline.
    static let chipFontSize: CGFloat = 12
    static let chipFont = Font.system(size: chipFontSize, weight: .medium)
    static let chipCornerRadius: CGFloat = 4
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 1
    static let chipOutlineWidth: CGFloat = 1
    /// The pixels per point a key chip inside a line of text is drawn at: a Retina
    /// display's, fixed so the chip does not depend on the screen that draws it.
    static let chipImageScale: CGFloat = 2
}
