import AppKit
import CoreGraphics
@testable import HintjumpUI
import SwiftUI
import Testing

/// One status-icon contact sheet: the icon in every state, on a strip that stands in for
/// the menu bar in one appearance, at one magnification.
struct StatusIconSheet: CustomTestStringConvertible {
    enum Appearance: String {
        case light
        case dark
    }

    let appearance: Appearance
    /// Pixels per point: 2 is a Retina menu bar at the icon's real 18 pt; the enlarged
    /// sheet redraws the same vector artwork at 8 pixels per point, to judge its shape.
    let scale: CGFloat

    /// The reference image's file name, without the extension.
    var name: String {
        scale == StatusIconRenderingTests.actualScale
            ? "status-icon-\(appearance.rawValue)"
            : "status-icon-\(appearance.rawValue)-enlarged"
    }

    var testDescription: String {
        name
    }
}

/// The status icon and its overlays, checked without a menu bar, a window, or a TCC grant.
///
/// Each sheet draws, left to right: the icon in the normal state, with the update dot,
/// and with the config-error "!". The real-size sheets are what the owner judges the
/// overlays' legibility from (#70). The icons are the app's own template images
/// (``StatusIcon/image(for:)``), tinted with the appearance's primary label colour on a
/// flat stand-in for the menu bar: the real menu bar is translucent over the wallpaper,
/// which no off-screen render reproduces.
@Suite("The status icon, rendered off screen, against its reference images")
struct StatusIconRenderingTests {
    /// A Retina display's pixels per point: the icon at the size the menu bar shows it.
    static let actualScale: CGFloat = 2
    /// The enlarged sheets' pixels per point.
    static let enlargedScale: CGFloat = 8

    /// The menu bar's height on a display without a notch.
    static let menuBarHeight: CGFloat = 24
    /// The gap between status items, and the margin at either end of the strip.
    static let itemSpacing: CGFloat = 12

    static let lightMenuBar = Color(.sRGB, red: 0.93, green: 0.93, blue: 0.93)
    static let darkMenuBar = Color(.sRGB, red: 0.14, green: 0.14, blue: 0.15)

    /// Every state a sheet shows, in the order the suite's summary lists them.
    static let states: [StatusIconState] = [.normal, .updateAvailable, .configError]

    static let sheets: [StatusIconSheet] = [
        StatusIconSheet(appearance: .light, scale: actualScale),
        StatusIconSheet(appearance: .dark, scale: actualScale),
        StatusIconSheet(appearance: .light, scale: enlargedScale),
        StatusIconSheet(appearance: .dark, scale: enlargedScale),
    ]

    /// `sheet` rendered off screen, or `nil` when the renderer produced nothing.
    @MainActor
    static func image(of sheet: StatusIconSheet) -> CGImage? {
        let content = HStack(spacing: itemSpacing) {
            ForEach(states, id: \.self) { state in
                StatusIcon.image(for: state)
                    .frame(width: StatusIcon.size.width, height: StatusIcon.size.height)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, itemSpacing)
        .frame(height: menuBarHeight)
        .background(sheet.appearance == .light ? lightMenuBar : darkMenuBar)
        .environment(\.colorScheme, sheet.appearance == .light ? .light : .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = sheet.scale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    /// One icon alone on a transparent background at ``actualScale``, tinted opaque black
    /// so a pixel's alpha is the artwork's coverage.
    @MainActor
    static func pixels(of state: StatusIconState) throws -> RGBAPixels {
        let renderer = ImageRenderer(
            content: StatusIcon.image(for: state)
                .frame(width: StatusIcon.size.width, height: StatusIcon.size.height)
                .foregroundStyle(.black),
        )
        renderer.scale = actualScale
        return try RGBAPixels(#require(renderer.cgImage))
    }

    /// The alpha of the pixel under `point`, measured from the top left.
    static func alpha(of pixels: RGBAPixels, at point: CGPoint) -> UInt8 {
        let column = Int(point.x * actualScale)
        let row = Int(point.y * actualScale)
        let alphaChannel = 3
        return pixels.bytes[(row * pixels.width + column) * RGBAPixels.bytesPerPixel + alphaChannel]
    }

    @Test(arguments: Self.sheets)
    @MainActor
    func `renders exactly as its reference image`(sheet: StatusIconSheet) throws {
        let rendered = try #require(
            Self.image(of: sheet),
            "ImageRenderer produced no image for \(sheet.name)",
        )
        try ReferenceImages.check(rendered, named: sheet.name)
    }

    /// The menu bar tints a template image for its appearance, and only a template's
    /// alpha survives that tinting; the size is the menu bar's icon size.
    @Test(arguments: StatusIconState.allCases)
    func `is an 18 pt template image`(state: StatusIconState) {
        let image = StatusIcon.nsImage(for: state)

        #expect(image.isTemplate)
        #expect(image.size == CGSize(width: 18, height: 18))
        #expect(image.accessibilityDescription == "Hintjump")
    }

    /// The tag is an outline, never a filled box: its stroke is opaque, and the space
    /// between the stroke and the arrow is clear, in every state.
    @Test(arguments: StatusIconState.allCases)
    @MainActor
    func `draws the tag as an outline, never filled`(state: StatusIconState) throws {
        let pixels = try Self.pixels(of: state)
        let middle: CGFloat = 9
        let onTheStroke: CGFloat = 1.75
        let insideTheStroke: CGFloat = 2.75

        #expect(Self.alpha(of: pixels, at: CGPoint(x: onTheStroke, y: middle)) == .max)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: insideTheStroke, y: middle)) == 0)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: middle, y: onTheStroke)) == .max)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: middle, y: insideTheStroke)) == 0)
    }

    /// The comparison is not vacuous: every state draws differently.
    @Test
    @MainActor
    func `every state renders to different pixels`() throws {
        let images = try StatusIconState.allCases.map { try Self.pixels(of: $0) }

        for (index, image) in images.enumerated() {
            for other in images[(index + 1)...] {
                let difference = PixelDifference(actual: image, reference: other, tolerance: 0)
                #expect(difference.differingPixels > 0)
            }
        }
    }

    /// An overlay's cut-out stops short of the arrow: every pixel the arrow covers in the
    /// normal state is drawn the same with an overlay, so no overlay clips or touches it.
    @Test(arguments: [StatusIconState.updateAvailable, .configError])
    @MainActor
    func `an overlay leaves the arrow whole`(state: StatusIconState) throws {
        let normal = try Self.pixels(of: .normal)
        let overlaid = try Self.pixels(of: state)
        // The arrow's bounds, in pixels from the top left: 5.5–12.5 pt across, 4–14.5 pt down.
        let columns = 11 ..< 25
        let rows = 8 ..< 29
        let alphaChannel = 3

        var changed = 0
        for row in rows {
            for column in columns {
                let alpha = (row * normal.width + column) * RGBAPixels.bytesPerPixel + alphaChannel
                if normal.bytes[alpha] > 0, overlaid.bytes[alpha] != normal.bytes[alpha] {
                    changed += 1
                }
            }
        }
        #expect(changed == 0)
    }

    /// The "!" reads as one at the menu bar's real size, not only enlarged (#70): down the
    /// badge's middle, at 2 pixels per point, the badge is solid above a clear bar, solid
    /// again across the gap, clear at the point, and solid below it — so the bar and the
    /// point are separate holes, each a few pixels across, not one blurred smudge.
    @Test
    @MainActor
    func `the config-error mark is a legible "!" at real size`() throws {
        let pixels = try Self.pixels(of: .configError)
        let middle: CGFloat = 15.75
        let expected: [(down: CGFloat, alpha: UInt8)] = [
            (down: 8.75, alpha: .max), // the badge above the bar
            (down: 11.5, alpha: 0), // the bar
            (down: 14.5, alpha: .max), // the gap
            (down: 15.75, alpha: 0), // the point
            (down: 17.25, alpha: .max), // the badge below the point
        ]

        for (down, alpha) in expected {
            #expect(Self.alpha(of: pixels, at: CGPoint(x: middle, y: down)) == alpha)
        }
    }
}
