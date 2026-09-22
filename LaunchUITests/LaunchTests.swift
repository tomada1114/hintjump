import XCTest

/// The agent app's launch guarantee: it starts and puts its item in the menu bar.
///
/// There is no window to wait for — `LSUIElement` makes the status item the app's
/// whole visible surface.
///
/// XCTest by necessity — Apple has not ported UI automation to Swift Testing.
/// All other tests use Swift Testing in Packages/HintjumpKit.
final class LaunchTests: XCTestCase {
    private enum Timeout {
        static let statusItemAppears: TimeInterval = 10
    }

    @MainActor
    func testAppLaunchesAndShowsItsStatusItem() {
        // A failed launch assertion should end the test immediately instead of
        // cascading through the remaining waits against a dead app.
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launch()

        // An accessory app never reaches the foreground: `app.windows` stays empty and
        // `app.state` stays `.runningBackground`. The status item is the assertion —
        // it sits in a second `menuBars` element of the app's own accessibility tree,
        // beside the main menu an agent app never shows. Do not add `isHittable`: a
        // background app's status item reports false until something activates the app,
        // which `click()` does for itself.
        let statusItem = app.menuBars.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: Timeout.statusItemAppears))
    }
}
