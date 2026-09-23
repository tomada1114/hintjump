import AppKit

/// The status icon's geometry, in points on the 18 × 18 pt canvas with the origin at the
/// bottom left (the image is not flipped). Edges sit on half-point boundaries so they land
/// on whole pixels on a Retina display.
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

    /// The pointer, the classic arrow with its tip at the top left: the left edge, the
    /// notch where the tail leaves the head, the tail, and the head's wing. Its box,
    /// 5.5–12.5 pt across, is centred on the tag's interior, which leaves the wing's tip
    /// a point clear of the config-error badge.
    static let pointerLeft: CGFloat = 5.5
    static let pointerTop: CGFloat = 14
    static let pointerBottom: CGFloat = 4.5
    static let notchX: CGFloat = 7.75
    static let notchY: CGFloat = 6.75
    static let tailInnerX: CGFloat = 9.25
    static let tailBottom: CGFloat = 3.5
    static let tailOuterX: CGFloat = 10.75
    static let tailOuterY: CGFloat = 4.25
    static let wingX: CGFloat = 12.5
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

    /// The update dot, over the tag's bottom-right corner, and the clear disc cut around
    /// it so it never touches the tag's outline.
    static let dotX: CGFloat = 15
    static let dotY: CGFloat = 3
    static let dotRadius: CGFloat = 2.25
    static let dotKnockoutRadius: CGFloat = 3.5

    /// The config-error badge: a filled pill standing in the tag's bottom-right corner,
    /// with a "!" knocked out of it. A pill, not a disc, so its shape alone tells it from
    /// the update dot; filled, so it stands apart from the stroked outline instead of
    /// reading as a break in it; and tall, so the "!" in it is three pixels wide and
    /// fourteen tall at the menu bar's real size — a mark, not a speck (#70).
    static let badgeLeft: CGFloat = 13.5
    static let badgeWidth: CGFloat = 4.5
    static let badgeHeight: CGFloat = 10
    static let badge = CGRect(x: badgeLeft, y: 0, width: badgeWidth, height: badgeHeight)
    /// Half the width, so the pill's ends are round.
    static let badgeRadius: CGFloat = 2.25
    /// The "!" cut out of the badge, centred on it: a bar with rounded ends, a clear gap
    /// two pixels tall, and a round point.
    static let alertWidth: CGFloat = 1.5
    /// Half the width, so the bar's ends are round.
    static let alertRounding: CGFloat = 0.75
    /// Centred on the badge: 1.5 pt of badge on either side.
    static let alertLeft: CGFloat = 15
    static let alertPointBottom: CGFloat = 1.5
    static let alertBarBottom: CGFloat = 4
    static let alertBarHeight: CGFloat = 4.5
    static let alertBar = CGRect(
        x: alertLeft,
        y: alertBarBottom,
        width: alertWidth,
        height: alertBarHeight,
    )
    static let alertPoint = CGRect(
        x: alertLeft,
        y: alertPointBottom,
        width: alertWidth,
        height: alertWidth,
    )
    /// The clear space cut around the badge, which keeps it off the tag's outline and
    /// clear of the arrow's wing.
    static let badgeClearance: CGFloat = 0.75
    static let badgeKnockout = badge.insetBy(dx: -badgeClearance, dy: -badgeClearance)
}

/// Draws the icon in one state into a graphics context, in solid black: the image is a
/// template, so only coverage matters and the menu bar supplies the colour.
struct StatusIconArtwork {
    let state: StatusIconState

    /// The clear area cut out of the tag around this state's overlay, so the overlay
    /// stands apart from the tag's corner rather than merging into it; `nil` for none.
    private var knockout: CGPath? {
        switch state {
        case .normal:
            nil

        case .updateAvailable:
            CGPath(ellipseIn: Self.dotDisc(radius: Metrics.dotKnockoutRadius), transform: nil)

        case .configError:
            CGPath(
                roundedRect: Metrics.badgeKnockout,
                cornerWidth: Metrics.badgeRadius + Metrics.badgeClearance,
                cornerHeight: Metrics.badgeRadius + Metrics.badgeClearance,
                transform: nil,
            )
        }
    }

    /// A disc of `radius` around the update dot's centre.
    private static func dotDisc(radius: CGFloat) -> CGRect {
        CGRect(
            x: Metrics.dotX - radius,
            y: Metrics.dotY - radius,
            width: radius + radius,
            height: radius + radius,
        )
    }

    private static func pointer() -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: Metrics.pointer)
        path.closeSubpath()
        return path
    }

    func draw(in context: CGContext) {
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))

        context.saveGState()
        if let knockout {
            let clip = CGMutablePath()
            clip.addRect(CGRect(origin: .zero, size: StatusIcon.size))
            clip.addPath(knockout)
            context.addPath(clip)
            context.clip(using: .evenOdd)
        }
        drawTag(in: context)
        context.addPath(Self.pointer())
        context.fillPath()
        context.restoreGState()

        drawOverlay(in: context)
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

    private func drawOverlay(in context: CGContext) {
        switch state {
        case .normal:
            return

        case .updateAvailable:
            context.addEllipse(in: Self.dotDisc(radius: Metrics.dotRadius))
            context.fillPath()

        case .configError:
            // Even-odd, so the "!" inside the pill is a hole the menu bar shows through.
            context.addPath(CGPath(
                roundedRect: Metrics.badge,
                cornerWidth: Metrics.badgeRadius,
                cornerHeight: Metrics.badgeRadius,
                transform: nil,
            ))
            context.addPath(CGPath(
                roundedRect: Metrics.alertBar,
                cornerWidth: Metrics.alertRounding,
                cornerHeight: Metrics.alertRounding,
                transform: nil,
            ))
            context.addEllipse(in: Metrics.alertPoint)
            context.fillPath(using: .evenOdd)
        }
    }
}
