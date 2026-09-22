import CoreGraphics
import HintjumpCore
import Testing

extension HintSessionTests {
    /// From a typed key to a narrowing, a click, or nothing at all.
    @MainActor
    @Suite("keys")
    struct Keys {
        /// With the default 26 characters and 16 singles, the 17th and 18th targets are
        /// labeled `ia` and `is`.
        static let pairCount = 18

        @Test
        func `typing a single hides the hints, then clicks on the next turn`() {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.type("s")

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.clicker.clicks.isEmpty)

            fixture.turns.runAll()

            #expect(fixture.clicker.clicks == [
                .init(point: HintSessionTests.targets(count: 3)[1].clickPoint, button: .left),
            ])
        }

        @Test
        func `a right-click trigger clicks with the right button`() {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.rightClickInWindow)

            fixture.presenter.type("a")
            fixture.turns.runAll()

            #expect(fixture.clicker.clicks.map(\.button) == [.right])
        }

        @Test
        func `an upper-case character matches its lower-case label`() {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.type("A")
            fixture.turns.runAll()

            #expect(fixture.clicker.clicks
                .map(\.point) == [HintSessionTests.targets(count: 3)[0].clickPoint])
        }

        @Test
        func `a first character narrows to its labels with that character typed`() throws {
            let fixture = Fixture(targetCount: Self.pairCount)
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.type("i")

            let hints = try #require(fixture.session.overlay?.hints)
            #expect(hints.map(\.label) == ["ia", "is"])
            #expect(hints.map(\.typedCount) == [1, 1])
            let placed = HintSessionTests.hints(count: Self.pairCount)
            #expect(hints.map(\.center) == placed.suffix(2).map(\.center))
            #expect(fixture.presenter.hideCount == 0)
        }

        @Test
        func `the second character of a pair clicks its target`() {
            let fixture = Fixture(targetCount: Self.pairCount)
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.type("is")
            fixture.turns.runAll()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.clicker.clicks.map(\.point) == [
                HintSessionTests.targets(count: Self.pairCount)[17].clickPoint,
            ])
        }

        @Test
        func `backspace after a narrowing shows every hint again`() {
            let fixture = Fixture(targetCount: Self.pairCount)
            fixture.session.trigger(.clickInWindow)
            let shown = fixture.session.overlay

            fixture.presenter.type("i")
            fixture.presenter.type(.backspace)

            #expect(fixture.session.overlay == shown)
        }

        @Test(arguments: [HintKey.character("1"), .character("b"), .character("é"), .backspace])
        func `a key that means nothing leaves the hints as they are`(key: HintKey) {
            let fixture = Fixture(targetCount: Self.pairCount)
            fixture.session.trigger(.clickInWindow)
            let shown = fixture.session.overlay

            fixture.presenter.type(key)
            fixture.turns.runAll()

            #expect(fixture.session.overlay == shown)
            #expect(fixture.presenter.hideCount == 0)
            #expect(fixture.clicker.clicks.isEmpty)
        }

        @Test
        func `escape closes the hints without clicking`() {
            let fixture = Fixture(targetCount: Self.pairCount)
            fixture.session.trigger(.clickInWindow)
            fixture.presenter.type("i")

            fixture.presenter.type(.escape)
            fixture.turns.runAll()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.clicker.clicks.isEmpty)
        }

        @Test
        func `a key with no hints shown does nothing`() {
            let fixture = Fixture(targetCount: 3)

            fixture.session.handle(.character("a"))
            fixture.turns.runAll()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 0)
            #expect(fixture.clicker.clicks.isEmpty)
        }

        @Test
        func `a click the OS refuses is only logged`() {
            let fixture = Fixture(targetCount: 3)
            fixture.clicker.error = .notTrusted
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.type("a")
            fixture.turns.runAll()

            #expect(fixture.clicker.clicks.count == 1)
            #expect(fixture.session.overlay == nil)

            // The session is ready for the next press.
            fixture.session.trigger(.clickInWindow)
            #expect(fixture.session.overlay != nil)
        }
    }
}
