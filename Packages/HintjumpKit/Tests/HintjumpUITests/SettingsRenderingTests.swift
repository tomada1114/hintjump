import AppKit
import CoreGraphics
import HintjumpCore
@testable import HintjumpUI
import SwiftUI
import Testing

/// The Settings window, rendered off screen, against its reference images: every pane in
/// light and dark, with the attention tiles on and off.
///
/// Drawn by an `NSHostingView` into a bitmap rather than by `ImageRenderer`, which draws
/// the AppKit-backed controls a pane is made of — the grouped `Form`, its buttons, a
/// `Link` — as a placeholder. It still needs no window, no display, and no grant, so it
/// runs under `just test` and in CI like the other rendering suites. The bitmap's size,
/// scale, and color space are fixed here, so the image does not depend on the screen of
/// the machine that draws it.
///
/// The sidebar is the exception: a `List` in a split view draws nothing without a
/// window, so the scene stands the window's sidebar in with the real rows
/// (``SettingsSidebarRow``) on a flat sidebar color, and the selected row on the system
/// blue the contrast table in `docs/design/settings-window.md` measured against —
/// covering the case the spec asks for, an attention tile on a selected row.
@MainActor
@Suite("The Settings window, rendered off screen, against its reference images")
struct SettingsRenderingTests {
    /// The window's sidebar: the real rows, on the sidebar's light or dark color, with the
    /// selected one on the system blue.
    private struct SidebarStandIn: View {
        static let rowSpacing: CGFloat = 2
        static let rowHorizontalPadding: CGFloat = 8
        static let rowVerticalPadding: CGFloat = 4
        static let selectionCornerRadius: CGFloat = 6
        static let padding: CGFloat = 10

        let model: SettingsViewModel
        let appearance: SettingsScene.Appearance

        var body: some View {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(model.panes) { pane in
                    SettingsSidebarRow(pane: pane, model: model)
                        .padding(.horizontal, Self.rowHorizontalPadding)
                        .padding(.vertical, Self.rowVerticalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(pane == model.selection ? Color.white : Color.primary)
                        .background {
                            RoundedRectangle(cornerRadius: Self.selectionCornerRadius)
                                .fill(pane == model.selection ? selectionColor : Color.clear)
                        }
                }
                Spacer()
            }
            .padding(Self.padding)
            .frame(width: SettingsLayout.sidebarWidth)
            .background(sidebarColor)
        }

        /// `#ECECEC` and `#323232`, the window backgrounds the spec's contrast table uses.
        private var sidebarColor: Color {
            appearance == .light
                ? Color(.sRGB, red: 0.925, green: 0.925, blue: 0.925)
                : Color(.sRGB, red: 0.196, green: 0.196, blue: 0.196)
        }

        /// `#007AFF` and `#0A84FF`, the default system blue in each appearance.
        private var selectionColor: Color {
            appearance == .light
                ? Color(.sRGB, red: 0, green: 0.478, blue: 1)
                : Color(.sRGB, red: 0.039, green: 0.518, blue: 1)
        }
    }

    /// The window's minimum width, and tall enough for the longest pane, Getting Started,
    /// to show all three of its sections without scrolling.
    static let size = CGSize(width: SettingsLayout.minWidth, height: 620)
    /// A Retina display's pixels per point.
    static let scale: CGFloat = 2

    /// `scene` drawn into a bitmap, or `nil` when AppKit produced none.
    static func image(of scene: SettingsScene) -> CGImage? {
        let model = SettingsSceneModel.model(for: scene)
        let content = HStack(spacing: 0) {
            SidebarStandIn(model: model, appearance: scene.appearance)
            SettingsDetail(model: model)
        }
        // The system accent, pinned: a `Link` takes the user's accent color otherwise.
        .tint(Color(.sRGB, red: 0, green: 0.478, blue: 1))
        .frame(width: size.width, height: size.height)
        return render(content, dark: scene.appearance == .dark)
    }

    /// `view` drawn by an `NSHostingView` into an sRGB bitmap of ``size`` at ``scale``.
    static func render(_ view: some View, dark: Bool) -> CGImage? {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0,
        )?.retagging(with: .sRGB) else {
            return nil
        }
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap.cgImage
    }

    @Test(arguments: SettingsScene.all)
    func `renders exactly as its reference image`(scene: SettingsScene) throws {
        let rendered = try #require(
            Self.image(of: scene),
            "NSHostingView produced no image for \(scene.name)",
        )
        try ReferenceImages.check(rendered, named: scene.name)
    }

    /// The comparison is not vacuous: the attention tile draws differently from a normal
    /// one, on its own and in the sidebar.
    @Test
    func `an attention tile draws differently from a normal one`() throws {
        func pixels(_ attention: Bool) throws -> RGBAPixels {
            let renderer = ImageRenderer(
                content: PaneTile(
                    symbolName: SettingsPane.gettingStarted.symbolName,
                    needsAttention: attention,
                ),
            )
            renderer.scale = Self.scale
            return try RGBAPixels(#require(renderer.cgImage))
        }
        let difference = try PixelDifference(
            actual: pixels(true),
            reference: pixels(false),
            tolerance: 0,
        )

        #expect(difference.differingPixels > 0)
    }
}
