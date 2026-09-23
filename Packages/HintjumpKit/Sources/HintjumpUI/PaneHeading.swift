import HintjumpCore
import SwiftUI

/// A pane's heading — its name — drawn as the header of the pane's first section, over
/// that section's own header when it has one.
///
/// Inside the form rather than above it, so it scrolls with the pane and sits on the
/// form's own background in either appearance; and not the navigation title, which
/// would replace the window's own title, "Hintjump Settings".
struct PaneHeading: View {
    let pane: SettingsPane
    /// The first section's own header, e.g. "Allow Accessibility", or `nil`.
    let sectionHeader: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsLayout.headingSpacing) {
            Text(pane.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            if let sectionHeader {
                Text(sectionHeader)
            }
        }
    }
}
