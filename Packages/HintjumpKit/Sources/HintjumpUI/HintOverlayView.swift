import HintjumpCore
import SwiftUI

/// The overlay's provisional palette and type, replaced by `docs/design/design-system.md`
/// when #21 lands. Fixed regardless of system appearance: the tags sit over other apps'
/// light and dark content alike (`docs/decisions.md` › "Design: signpost hints, one
/// accent, system controls everywhere else", amended by #113). Every label gets the same
/// yellow tag with near-black uppercase text, whatever its length; the right-click entry
/// point inverts it. Sizes come from ``HintLayout``, which Core placed the tags with.
enum Palette {
    private static let channelMax: Double = 255
    private static let channelMask: UInt32 = 0xFF
    private static let redShift: UInt32 = 16
    private static let greenShift: UInt32 = 8

    private static let yellowRGB: UInt32 = 0xFFD60A
    private static let inkRGB: UInt32 = 0x1C1C1E
    private static let labelFontSize: CGFloat = 12
    private static let chipFontSize: CGFloat = 11

    /// The tag yellow, `#FFD60A`: the fill of a left-click tag, the text and outline of a
    /// right-click one.
    static let yellow = color(yellowRGB)
    /// The near-black ink, `#1C1C1E`: the text and outline of a left-click tag, the fill
    /// of a right-click one.
    static let ink = color(inkRGB)
    /// How an already-typed character is dimmed.
    static let typedOpacity = 0.4

    static let cornerRadius: CGFloat = 4
    /// The outline drawn just inside every tag. On a light background it is what
    /// separates a yellow tag; on a dark one the fill does.
    static let outlineWidth: CGFloat = 1
    /// Bold monospaced type, shown uppercased: capitals of one height read faster than
    /// lowercase letters. Monospaced, because the proportional system bold puts `WW` wider
    /// than ``HintjumpCore/HintLayout/pairTagWidth`` allows, while every pair here takes
    /// the same width and fits with room to spare.
    static let labelFont = Font.system(size: labelFontSize, weight: .bold, design: .monospaced)
    static let chipFont = Font.system(size: chipFontSize, weight: .semibold)
    static let chipPadding: CGFloat = 8

    /// The fill, the text, and the outline for `style`.
    static func colors(for style: HintStyle) -> TagColors {
        switch style {
        case .filled:
            TagColors(fill: yellow, text: ink, outline: ink)

        case .outlined:
            TagColors(fill: ink, text: yellow, outline: yellow)
        }
    }

    /// The sRGB color `0xRRGGBB` names.
    private static func color(_ rgb: UInt32) -> Color {
        func channel(_ shift: UInt32) -> Double {
            Double((rgb >> shift) & channelMask) / channelMax
        }
        return Color(.sRGB, red: channel(redShift), green: channel(greenShift), blue: channel(0))
    }
}

/// The three colors one tag is painted with.
struct TagColors {
    let fill: Color
    let text: Color
    let outline: Color
}

/// A tag's shape: a rounded box in `fill` with a 1 pt `outline` just inside its edge.
private struct TagBackground: View {
    let fill: Color
    let outline: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Palette.cornerRadius)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: Palette.cornerRadius)
                    .strokeBorder(outline, lineWidth: Palette.outlineWidth)
            }
    }
}

/// One hint tag, exactly `hint.size`, in the style its entry point uses.
private struct HintTag: View {
    let hint: PlacedHint
    let style: HintStyle

    var body: some View {
        let colors = Palette.colors(for: style)
        // Labels are shown uppercased; typing is unchanged, since the session lowercases
        // what is typed.
        HStack(spacing: 0) {
            Text(hint.label.prefix(hint.typedCount).uppercased())
                .foregroundStyle(colors.text.opacity(Palette.typedOpacity))
            Text(hint.label.dropFirst(hint.typedCount).uppercased())
                .foregroundStyle(colors.text)
        }
        .font(Palette.labelFont)
        .lineLimit(1)
        .fixedSize()
        .frame(width: hint.size.width, height: hint.size.height)
        .background(TagBackground(fill: colors.fill, outline: colors.outline))
    }
}

/// The right-click entry point's "Right click" chip, in the inverted right-click style.
private struct ChipTag: View {
    let chip: PlacedChip

    var body: some View {
        Text(chip.text)
            .font(Palette.chipFont)
            .foregroundStyle(Palette.colors(for: .outlined).text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Palette.chipPadding)
            .frame(width: chip.size.width, height: chip.size.height)
            .background(TagBackground(
                fill: Palette.colors(for: .outlined).fill,
                outline: Palette.colors(for: .outlined).outline,
            ))
    }
}

/// What the overlay draws for one ``HintjumpCore/HintOverlayState``, or nothing for `nil`.
///
/// Split from ``HintOverlayView`` so that a test can render a state it built by hand, off
/// screen, without a ``HintjumpCore/HintSession`` to drive there.
struct HintOverlayCanvas: View {
    let overlay: HintOverlayState?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let overlay {
                ForEach(overlay.hints, id: \.label) { hint in
                    HintTag(hint: hint, style: overlay.style)
                        .position(hint.center)
                }
                if let chip = overlay.chip {
                    ChipTag(chip: chip)
                        .position(chip.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The hint overlay: renders ``HintjumpCore/HintSession/overlay`` and nothing else.
///
/// Every position and size was decided in Core (``HintjumpCore/HintLayout``), relative to
/// the canvas's top-left corner — the same corner SwiftUI measures from, so a center is
/// used as given. Nothing animates (`docs/decisions.md` › "Design: signpost hints, one
/// accent, system controls everywhere else"): the whole tree runs with animations
/// disabled, so narrowing removes tags at once.
public struct HintOverlayView: View {
    private let session: HintSession

    public var body: some View {
        HintOverlayCanvas(overlay: session.overlay)
            // The canvas is the whole screen, menu bar and notch included: a safe-area
            // inset would shift every tag off its target.
            .ignoresSafeArea()
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
    }

    /// The view over `session`, whose ``HintjumpCore/HintSession/overlay`` it observes.
    public init(session: HintSession) {
        self.session = session
    }
}
