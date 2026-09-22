import HintjumpCore
import SwiftUI

/// The overlay's provisional palette and type, replaced by `docs/design/design-system.md`
/// when #21 lands. Fixed regardless of system appearance: the tags sit over other apps'
/// light and dark content alike (`docs/decisions.md` › "Design: signpost hints, one
/// accent, system controls everywhere else"). Sizes come from ``HintLayout``, which Core
/// placed the tags with.
private enum Palette {
    private static let channelMax: Double = 255
    private static let channelMask: UInt32 = 0xFF
    private static let redShift: UInt32 = 16
    private static let greenShift: UInt32 = 8

    private static let tagRGB: UInt32 = 0x1C1C1E
    private static let accentRGB: UInt32 = 0xE5470F
    private static let haloOpacity = 0.6
    private static let labelFontSize: CGFloat = 12
    private static let chipFontSize: CGFloat = 11

    /// The near-black tag fill, `#1C1C1E`.
    static let tag = color(tagRGB)
    /// The one accent, `#E5470F`, that marks a single-character hint.
    static let accent = color(accentRGB)
    static let text = Color.white
    /// The light halo that cuts a tag out of a dark background.
    static let halo = Color.white.opacity(haloOpacity)
    /// How an already-typed character is dimmed.
    static let typedOpacity = 0.4

    static let cornerRadius: CGFloat = 4
    static let haloWidth: CGFloat = 1
    static let outlineWidth: CGFloat = 1.5
    static let labelFont = Font.system(size: labelFontSize, weight: .bold, design: .monospaced)
    static let chipFont = Font.system(size: chipFontSize, weight: .semibold)
    static let chipPadding: CGFloat = 8

    /// The sRGB color `0xRRGGBB` names.
    private static func color(_ rgb: UInt32) -> Color {
        func channel(_ shift: UInt32) -> Double {
            Double((rgb >> shift) & channelMask) / channelMax
        }
        return Color(.sRGB, red: channel(redShift), green: channel(greenShift), blue: channel(0))
    }
}

/// A tag's shape and its halo: the near-black (or accent) rounded box with a 1 pt light
/// ring drawn just outside it.
private struct TagBackground: View {
    let fill: Color
    let outline: Color?

    var body: some View {
        RoundedRectangle(cornerRadius: Palette.cornerRadius)
            .fill(fill)
            .overlay {
                if let outline {
                    RoundedRectangle(cornerRadius: Palette.cornerRadius)
                        .strokeBorder(outline, lineWidth: Palette.outlineWidth)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: Palette.cornerRadius + Palette.haloWidth)
                    .fill(Palette.halo)
                    .padding(-Palette.haloWidth)
            }
    }
}

/// One hint tag, exactly `hint.size`, in the style its entry point uses.
private struct HintTag: View {
    let hint: PlacedHint
    let style: HintStyle

    private var fill: Color {
        style == .filled && hint.isSingle ? Palette.accent : Palette.tag
    }

    private var outline: Color? {
        guard style == .outlined else {
            return nil
        }
        return hint.isSingle ? Palette.accent : Palette.text
    }

    private var textColor: Color {
        style == .outlined && hint.isSingle ? Palette.accent : Palette.text
    }

    var body: some View {
        // Labels render as the lowercase letters the user types: no uppercasing.
        HStack(spacing: 0) {
            Text(hint.label.prefix(hint.typedCount))
                .foregroundStyle(textColor.opacity(Palette.typedOpacity))
            Text(hint.label.dropFirst(hint.typedCount))
                .foregroundStyle(textColor)
        }
        .font(Palette.labelFont)
        .lineLimit(1)
        .fixedSize()
        .frame(width: hint.size.width, height: hint.size.height)
        .background(TagBackground(fill: fill, outline: outline))
    }
}

/// The right-click entry point's "Right click" chip.
private struct ChipTag: View {
    let chip: PlacedChip

    var body: some View {
        Text(chip.text)
            .font(Palette.chipFont)
            .foregroundStyle(Palette.text)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Palette.chipPadding)
            .frame(width: chip.size.width, height: chip.size.height)
            .background(TagBackground(fill: Palette.tag, outline: nil))
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
