import AppKit
import HintjumpCore
import SwiftUI

/// Layout metrics for ``SettingsView`` (`docs/design/settings-window.md` › Window).
enum SettingsLayout {
    /// The sidebar's width, which the user cannot change or collapse.
    static let sidebarWidth: CGFloat = 200
    /// The window's minimum content size.
    static let minWidth: CGFloat = 680
    static let minHeight: CGFloat = 460
    /// The space between a pane's heading and its first section's header.
    static let headingSpacing: CGFloat = 12
}

/// The Settings window: a fixed sidebar of hint-tag tiles and a grouped form beside it
/// (`docs/design/settings-window.md`).
///
/// Thin, as every view here is: which pane shows, which tiles take the accent, and what
/// each pane says are all ``HintjumpCore/SettingsViewModel``'s. `App/` builds the model
/// over the real ports and hands it down.
public struct SettingsView: View {
    private let model: SettingsViewModel

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: selection) {
                ForEach(model.panes) { pane in
                    SettingsSidebarRow(pane: pane, model: model)
                        .tag(pane)
                }
            }
            .navigationSplitViewColumnWidth(SettingsLayout.sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            SettingsDetail(model: model)
        }
        .navigationTitle(SettingsCopy.windowTitle)
        .frame(minWidth: SettingsLayout.minWidth, minHeight: SettingsLayout.minHeight)
        // What the window cannot be told — a grant given in System Settings, a file
        // deleted in Finder — is asked again when it opens and whenever the app comes
        // back to the front.
        .onAppear {
            model.refresh()
        }
        .onReceive(appBecameActive) { _ in
            model.refresh()
        }
    }

    /// Posted whenever Hintjump comes back to the front, e.g. from System Settings.
    private var appBecameActive: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    }

    /// The list's selection, handed to the model, which keeps the pane that was showing
    /// when the list reports none.
    private var selection: Binding<SettingsPane?> {
        Binding {
            model.selection
        } set: { pane in
            model.select(pane)
        }
    }

    /// Creates the window's content over `model`, which `App/` builds once and keeps,
    /// so the selected pane survives the window closing.
    public init(model: SettingsViewModel) {
        self.model = model
    }
}
