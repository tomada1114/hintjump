import AppKit
import SwiftUI

/// What the status icon has to say beyond "Hintjump is running".
///
/// One case at a time, never two: when an update is available and the config file is
/// broken, only ``configError`` shows, because the error is the one that needs the user.
/// That choice belongs to Core once the two states exist (#19); until then the icon
/// simply draws the case it is handed.
public enum StatusIconState: Sendable, CaseIterable {
    /// The config file could not be applied: a small "!" at the bottom right.
    case configError
    /// Nothing to report: the tag and its glyph alone.
    case normal
    /// A newer version is available: a small dot at the bottom right.
    case updateAvailable
}

/// The three glyph candidates drawn inside the hint-tag outline, kept side by side until
/// the owner picks one (#19). The unpicked two are removed in that follow-up.
public enum StatusIconCandidate: String, Sendable, CaseIterable {
    /// Candidate A: one letter, `h`, in the hints' own bold monospaced face — the icon
    /// is a single-character hint.
    case letter
    /// Candidate B: a two-letter label, `hj`, in the same face — the icon is a
    /// two-character hint.
    case letterPair
    /// Candidate C: a pointer arrow — the tag is something to click.
    case pointer
}

/// The status item's image: a monochrome template, so the menu bar tints it for its
/// light or dark appearance the way it tints the SF Symbols beside it.
///
/// Drawn in code rather than shipped in `App/Assets.xcassets`, because the rendering tests
/// in `HintjumpUITests` must draw the very image the app shows, and `swift test` copies a
/// package's asset catalog without compiling it — an image in a catalog would exist for
/// the app and not for the tests. The drawing handler redraws the vector artwork at
/// whatever scale the image is drawn, so it is as crisp on a Retina menu bar as enlarged.
public enum StatusIcon {
    /// The candidate the status item shows. The owner's pick is this one line.
    public static let candidate = StatusIconCandidate.letter

    /// The icon's width and height, in points.
    static let side: CGFloat = 18

    /// The menu bar's icon size, in points.
    public static let size = CGSize(width: side, height: side)

    /// What VoiceOver says for the status item.
    static let accessibilityDescription = "Hintjump"

    /// The status icon for `state`, as the `MenuBarExtra` label takes it.
    ///
    /// - Parameter candidate: the glyph to draw; the default is ``candidate``, the one the
    ///   app shows. The rendering tests pass each one to draw them side by side.
    public static func image(
        for state: StatusIconState,
        candidate: StatusIconCandidate = candidate,
    ) -> Image {
        Image(nsImage: nsImage(for: state, candidate: candidate))
            .renderingMode(.template)
    }

    /// The same icon as a template `NSImage`, which is what the status item button
    /// ultimately draws.
    public static func nsImage(
        for state: StatusIconState,
        candidate: StatusIconCandidate = candidate,
    ) -> NSImage {
        let artwork = StatusIconArtwork(candidate: candidate, state: state)
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
