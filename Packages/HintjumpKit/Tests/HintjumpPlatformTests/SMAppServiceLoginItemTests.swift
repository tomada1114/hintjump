import HintjumpCore
import HintjumpPlatform
import Testing

/// The adapter against the real `ServiceManagement` API — read only.
///
/// What a Core test with a fake cannot ask: does `SMAppService.mainApp.status` really
/// answer, and does the adapter translate it to "not registered" for a process that
/// never registered itself? Everything downstream of that answer — when to register,
/// what a refusal does to a reload — stays a Core test against `FakeLoginItem`, where
/// the coverage floor sees it.
///
/// It never calls `setRegistered`: registering from a test would add the test runner to
/// the developer's Login Items. Reading needs no grant, so this runs from any terminal.
@Suite("SMAppServiceLoginItem against the real ServiceManagement API", .requiresLocalMachine)
@MainActor
struct SMAppServiceLoginItemTests {
    @Test
    func `reads the test runner as not registered, the same on every read`() {
        let loginItem = SMAppServiceLoginItem()

        // `SMAppService.mainApp` here is the test runner, which is never a login item —
        // so the only correct translation of its status is `false`.
        let first = loginItem.isRegistered
        let second = loginItem.isRegistered

        #expect(first == false)
        #expect(second == first)
    }
}
