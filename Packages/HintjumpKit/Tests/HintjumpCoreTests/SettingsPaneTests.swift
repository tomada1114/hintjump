@testable import HintjumpCore
import Testing

/// The sidebar's panes: their order, names, and symbols, as
/// `docs/design/settings-window.md` › Sidebar lists them.
@Suite("SettingsPane")
struct SettingsPaneTests {
    @Test
    func `lists the panes that have landed, in sidebar order`() {
        #expect(SettingsPane.allCases == [.gettingStarted, .configFile, .about])
    }

    @Test(arguments: [
        (SettingsPane.gettingStarted, "Getting Started", "hand.wave"),
        (.configFile, "Config File", "doc.text"),
        (.about, "About", "info.circle"),
    ])
    func `names each pane and its symbol as the spec does`(
        pane: SettingsPane,
        title: String,
        symbol: String,
    ) {
        #expect(pane.title == title)
        #expect(pane.symbolName == symbol)
        #expect(pane.id == pane)
    }
}
