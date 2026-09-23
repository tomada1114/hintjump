import AppKit
import CoreText

/// The status icon's geometry, in points on the 18 × 18 pt canvas with the origin at the
/// bottom left (the image is not flipped). Edges sit on half-point boundaries so a
/// 1.5 pt stroke lands on whole pixels on a Retina display.
private enum Metrics {
    /// SF Symbols' regular weight at menu-bar size, so the icon matches the ones beside it.
    static let strokeWidth: CGFloat = 1.5
    /// The hint tags' own corner radius (`docs/decisions.md` › "signpost hints").
    static let cornerRadius: CGFloat = 4

    /// The tag's stroke centre line starts this far in, so its outer edge spans
    /// 1–17 pt and leaves a 1 pt margin all round.
    static let tagInset: CGFloat = 1.75
    static let tagSide: CGFloat = 14.5
    static let tag = CGRect(x: tagInset, y: tagInset, width: tagSide, height: tagSide)

    /// Where a glyph is centred: the middle of the tag.
    static let middle: CGFloat = 9
    static let glyphCenter = CGPoint(x: middle, y: middle)

    /// Candidate A's letter, and the size its face is set at.
    static let letter = "h"
    static let letterSize: CGFloat = 12
    /// Candidate B's label, and the size its face is set at: smaller, to fit two.
    static let letterPair = "hj"
    static let letterPairSize: CGFloat = 9.5

    /// Candidate C's pointer, the classic arrow with its tip at the top left: the left
    /// edge, the notch where the tail leaves the head, the tail, and the head's wing.
    static let pointerLeft: CGFloat = 6
    static let pointerTop: CGFloat = 14
    static let pointerBottom: CGFloat = 4.5
    static let notchX: CGFloat = 8.25
    static let notchY: CGFloat = 6.75
    static let tailInnerX: CGFloat = 9.75
    static let tailBottom: CGFloat = 3.5
    static let tailOuterX: CGFloat = 11.25
    static let tailOuterY: CGFloat = 4.25
    static let wingX: CGFloat = 13
    static let wingY: CGFloat = 7.5
    static let pointer = [
        CGPoint(x: pointerLeft, y: pointerTop),
        CGPoint(x: pointerLeft, y: pointerBottom),
        CGPoint(x: notchX, y: notchY),
        CGPoint(x: tailInnerX, y: tailBottom),
        CGPoint(x: tailOuterX, y: tailOuterY),
        CGPoint(x: tailInnerX, y: wingY),
        CGPoint(x: wingX, y: wingY),
    ]

    /// The overlays' centre, at the bottom right over the tag's corner.
    static let badgeX: CGFloat = 15
    static let badgeY: CGFloat = 3
    /// The clear disc cut around an overlay, so it never touches the tag's outline.
    static let knockoutRadius: CGFloat = 3.5
    /// The update dot's radius.
    static let dotRadius: CGFloat = 2.25
    /// The "!": a bar one stroke wide, and a point of the same width under it, both
    /// centred on `badgeX`.
    static let alertLeft: CGFloat = 14.25
    static let alertBarHeight: CGFloat = 3.25
    static let alertPointBottom: CGFloat = 0.5
    static let alertBar = CGRect(
        x: alertLeft,
        y: badgeY,
        width: strokeWidth,
        height: alertBarHeight,
    )
    static let alertPoint = CGRect(
        x: alertLeft,
        y: alertPointBottom,
        width: strokeWidth,
        height: strokeWidth,
    )
}

/// Draws one candidate in one state into a graphics context, in solid black: the image
/// is a template, so only coverage matters and the menu bar supplies the colour.
struct StatusIconArtwork {
    let candidate: StatusIconCandidate
    let state: StatusIconState

    /// A disc of `radius` around the overlays' centre.
    private static func disc(radius: CGFloat) -> CGRect {
        CGRect(
            x: Metrics.badgeX - radius,
            y: Metrics.badgeY - radius,
            width: radius + radius,
            height: radius + radius,
        )
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    /// `text` as glyph outlines in the hints' bold monospaced face, its ink centred on
    /// the tag. Outlines rather than drawn text, so the ink box — not the line box, which
    /// counts ascender and descender space the letters may not use — is what is centred.
    private static func letters(_ text: String, size: CGFloat) -> CGPath {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .bold) as CTFont
        let characters = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)

        let outlines = CGMutablePath()
        var penX: CGFloat = 0
        for (glyph, advance) in zip(glyphs, advances) {
            if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
                outlines.addPath(outline, transform: CGAffineTransform(translationX: penX, y: 0))
            }
            penX += advance.width
        }

        let ink = outlines.boundingBoxOfPath
        var centring = CGAffineTransform(
            translationX: Metrics.glyphCenter.x - ink.midX,
            y: Metrics.glyphCenter.y - ink.midY,
        )
        return outlines.copy(using: &centring) ?? outlines
    }

    func draw(in context: CGContext) {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))

        context.saveGState()
        if state != .normal {
            // Clip away a disc around the badge, so the badge stands apart from the
            // tag's corner rather than merging into it.
            let clip = CGMutablePath()
            clip.addRect(CGRect(origin: .zero, size: StatusIcon.size))
            clip.addEllipse(in: Self.disc(radius: Metrics.knockoutRadius))
            context.addPath(clip)
            context.clip(using: .evenOdd)
        }
        drawTag(in: context)
        drawGlyph(in: context)
        context.restoreGState()

        drawBadge(in: context)
    }

    /// The hint tag's outline: stroked, never filled.
    private func drawTag(in context: CGContext) {
        context.setLineWidth(Metrics.strokeWidth)
        context.addPath(CGPath(
            roundedRect: Metrics.tag,
            cornerWidth: Metrics.cornerRadius,
            cornerHeight: Metrics.cornerRadius,
            transform: nil,
        ))
        context.strokePath()
    }

    private func drawGlyph(in context: CGContext) {
        let glyph: CGPath = switch candidate {
        case .letter:
            Self.letters(Metrics.letter, size: Metrics.letterSize)

        case .letterPair:
            Self.letters(Metrics.letterPair, size: Metrics.letterPairSize)

        case .pointer:
            Self.polygon(Metrics.pointer)
        }
        context.addPath(glyph)
        context.fillPath()
    }

    private func drawBadge(in context: CGContext) {
        switch state {
        case .normal:
            return

        case .updateAvailable:
            context.addEllipse(in: Self.disc(radius: Metrics.dotRadius))

        case .configError:
            context.addRect(Metrics.alertBar)
            context.addEllipse(in: Metrics.alertPoint)
        }
        context.fillPath()
    }
}
