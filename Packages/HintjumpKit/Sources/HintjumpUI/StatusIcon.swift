import AppKit
import SwiftUI

/// What the status icon has to say beyond "Hintjump is running".
///
/// One case at a time, never two: when an update is available and the config file is
/// broken, only ``configError`` shows, because the error is the one that needs the user.
/// That choice belongs to Core once the two states exist (#19); until then the icon
/// simply draws the case it is handed.
public enum StatusIconState: Sendable, CaseIterable {
    /// The config file could not be applied: a "!" cut out of a filled pill at the bottom
    /// right.
    case configError
    /// Nothing to report: the tag and its arrow alone.
    case normal
    /// A newer version is available: a small dot at the bottom right.
    case updateAvailable
}

/// The status item's image: a pointer arrow inside the outline of a hint tag — a hint
/// on something to click — drawn as a monochrome template, so the menu bar tints it for
/// its light or dark appearance the way it tints the SF Symbols beside it. The arrow was
/// the owner's pick of three glyph candidates (#19, #70).
///
/// Drawn in code rather than shipped in `App/Assets.xcassets`, because the rendering tests
/// in `HintjumpUITests` must draw the very image the app shows, and `swift test` copies a
/// package's asset catalog without compiling it — an image in a catalog would exist for
/// the app and not for the tests. The drawing handler redraws the vector artwork at
/// whatever scale the image is drawn, so it is as crisp on a Retina menu bar as enlarged.
public enum StatusIcon {
    /// The icon's width and height, in points.
    static let side: CGFloat = 18

    /// The menu bar's icon size, in points.
    public static let size = CGSize(width: side, height: side)

    /// What VoiceOver says for the status item.
    static let accessibilityDescription = "Hintjump"

    /// The status icon for `state`, as the `MenuBarExtra` label takes it.
    public static func image(for state: StatusIconState) -> Image {
        Image(nsImage: nsImage(for: state))
            .renderingMode(.template)
    }

    /// The same icon as a template `NSImage`, which is what the status item button
    /// ultimately draws.
    public static func nsImage(for state: StatusIconState) -> NSImage {
        let artwork = StatusIconArtwork(state: state)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            artwork.draw(in: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}
