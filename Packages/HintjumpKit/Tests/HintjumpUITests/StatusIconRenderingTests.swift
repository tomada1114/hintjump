import AppKit
import CoreGraphics
@testable import HintjumpUI
import SwiftUI
import Testing

/// One status-icon contact sheet: every variant the owner chooses between, on a strip
/// that stands in for the menu bar in one appearance, at one magnification.
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

/// The status icon's candidates and overlays, checked without a menu bar, a window, or a
/// TCC grant — and, as reference images, what the owner picks a candidate from (#19).
///
/// Each sheet draws, left to right: candidate A, B, and C in the normal state, then
/// candidate A with the update dot, then candidate A with the config-error "!". The icons
/// are the app's own template images (``StatusIcon/image(for:candidate:)``), tinted with
/// the appearance's primary label colour on a flat stand-in for the menu bar: the real
/// menu bar is translucent over the wallpaper, which no off-screen render reproduces.
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

    /// Every variant a sheet shows, in the order the suite's summary lists them.
    static let variants: [(StatusIconCandidate, StatusIconState)] = [
        (.letter, .normal),
        (.letterPair, .normal),
        (.pointer, .normal),
        (.letter, .updateAvailable),
        (.letter, .configError),
    ]

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
            ForEach(variants.indices, id: \.self) { index in
                let (candidate, state) = variants[index]
                StatusIcon.image(for: state, candidate: candidate)
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
    static func pixels(
        of candidate: StatusIconCandidate,
        _ state: StatusIconState,
    ) throws -> RGBAPixels {
        let renderer = ImageRenderer(
            content: StatusIcon.image(for: state, candidate: candidate)
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
    @Test(arguments: StatusIconCandidate.allCases, StatusIconState.allCases)
    func `is an 18 pt template image`(
        candidate: StatusIconCandidate,
        state: StatusIconState,
    ) {
        let image = StatusIcon.nsImage(for: state, candidate: candidate)

        #expect(image.isTemplate)
        #expect(image.size == CGSize(width: 18, height: 18))
        #expect(image.accessibilityDescription == "Hintjump")
    }

    /// The tag is an outline, never a filled box: its stroke is opaque, and the space
    /// between the stroke and the glyph is clear, for every candidate in every state.
    @Test(arguments: StatusIconCandidate.allCases, StatusIconState.allCases)
    @MainActor
    func `draws the tag as an outline, never filled`(
        candidate: StatusIconCandidate,
        state: StatusIconState,
    ) throws {
        let pixels = try Self.pixels(of: candidate, state)
        let middle: CGFloat = 9
        let onTheStroke: CGFloat = 1.75
        let insideTheStroke: CGFloat = 2.75

        #expect(Self.alpha(of: pixels, at: CGPoint(x: onTheStroke, y: middle)) == .max)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: insideTheStroke, y: middle)) == 0)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: middle, y: onTheStroke)) == .max)
        #expect(Self.alpha(of: pixels, at: CGPoint(x: middle, y: insideTheStroke)) == 0)
    }

    /// The comparison is not vacuous: every candidate and every state draws differently.
    @Test
    @MainActor
    func `every candidate and state renders to different pixels`() throws {
        let images = try StatusIconCandidate.allCases.flatMap { candidate in
            try StatusIconState.allCases.map { state in
                try Self.pixels(of: candidate, state)
            }
        }

        for (index, image) in images.enumerated() {
            for other in images[(index + 1)...] {
                let difference = PixelDifference(actual: image, reference: other, tolerance: 0)
                #expect(difference.differingPixels > 0)
            }
        }
    }

    /// The pick is one line: the image the app shows is the chosen candidate's.
    @Test(arguments: StatusIconState.allCases)
    @MainActor
    func `draws the chosen candidate by default`(state: StatusIconState) throws {
        let chosen = try Self.pixels(of: StatusIcon.candidate, state)
        let renderer = ImageRenderer(
            content: StatusIcon.image(for: state)
                .frame(width: StatusIcon.size.width, height: StatusIcon.size.height)
                .foregroundStyle(.black),
        )
        renderer.scale = Self.actualScale
        let byDefault = try RGBAPixels(#require(renderer.cgImage))

        #expect(byDefault == chosen)
    }
}
