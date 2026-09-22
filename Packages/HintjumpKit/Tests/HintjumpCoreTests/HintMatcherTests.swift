import HintjumpCore
import Testing

@Suite("HintMatcher")
struct HintMatcherTests {
    /// 16 singles `a`…`u` and the first four pairs under `i`: `ia`, `is`, `id`, `if`.
    static let labels = LabelAssigner().labels(
        count: 20,
        characters: Array("asdfghjklqwertyuiopzxcvbnm"),
    )
    static let pairs = ["ia", "is", "id", "if"]

    /// A matcher that has already narrowed to the pairs under `i`.
    static func narrowed() -> HintMatcher {
        var matcher = HintMatcher(labels: labels)
        _ = matcher.handle(.character("i"))
        return matcher
    }

    // MARK: - Initial state

    @Test
    func `a new matcher shows every label and has nothing typed`() {
        let matcher = HintMatcher(labels: Self.labels)

        #expect(matcher.labels == Self.labels)
        #expect(matcher.typed.isEmpty)
        #expect(matcher.phase == .matching)
        #expect(matcher.candidates == Self.labels)
    }

    // MARK: - Characters

    @Test
    func `a single's character selects it`() {
        var matcher = HintMatcher(labels: Self.labels)

        #expect(matcher.handle(.character("s")) == .selected("s"))
        #expect(matcher.phase == .selected("s"))
    }

    @Test
    func `a prefix character narrows to the pairs starting with it`() {
        var matcher = HintMatcher(labels: Self.labels)

        #expect(matcher.handle(.character("i")) == .narrowed)
        #expect(matcher.typed == "i")
        #expect(matcher.phase == .matching)
        #expect(matcher.candidates == Self.pairs)
    }

    @Test(arguments: Self.pairs)
    func `a second character completes a pair`(label: String) throws {
        var matcher = Self.narrowed()
        let second = try #require(label.last)

        #expect(matcher.handle(.character(second)) == .selected(label))
        #expect(matcher.phase == .selected(label))
    }

    @Test(arguments: ["z", "m", "1", "A", "S", "é", " "] as [Character])
    func `a character no label starts with is ignored`(character: Character) {
        var matcher = HintMatcher(labels: Self.labels)
        let before = matcher

        #expect(matcher.handle(.character(character)) == .ignored)
        #expect(matcher == before)
    }

    @Test(arguments: ["g", "i", "o", "I"] as [Character])
    func `after narrowing, a character completing no pair is ignored`(character: Character) {
        var matcher = Self.narrowed()
        let before = matcher

        #expect(matcher.handle(.character(character)) == .ignored)
        #expect(matcher == before)
        #expect(matcher.candidates == Self.pairs)
    }

    // MARK: - Backspace

    @Test
    func `backspace after a narrowing undoes it`() {
        var matcher = Self.narrowed()

        #expect(matcher.handle(.backspace) == .widened)
        #expect(matcher.typed.isEmpty)
        #expect(matcher.phase == .matching)
        #expect(matcher.candidates == Self.labels)
    }

    @Test
    func `backspace with nothing typed is ignored`() {
        var matcher = HintMatcher(labels: Self.labels)
        let before = matcher

        #expect(matcher.handle(.backspace) == .ignored)
        #expect(matcher == before)
    }

    @Test
    func `after backspace a single can still be selected`() {
        var matcher = Self.narrowed()
        _ = matcher.handle(.backspace)

        #expect(matcher.handle(.character("a")) == .selected("a"))
    }

    @Test
    func `backspace then the same prefix narrows again`() {
        var matcher = Self.narrowed()
        _ = matcher.handle(.backspace)

        #expect(matcher.handle(.character("i")) == .narrowed)
        #expect(matcher.handle(.character("f")) == .selected("if"))
    }

    // MARK: - Escape

    @Test
    func `escape with nothing typed cancels`() {
        var matcher = HintMatcher(labels: Self.labels)

        #expect(matcher.handle(.escape) == .cancelled)
        #expect(matcher.phase == .cancelled)
    }

    @Test
    func `escape after a narrowing cancels rather than undoing it`() {
        var matcher = Self.narrowed()

        #expect(matcher.handle(.escape) == .cancelled)
        #expect(matcher.phase == .cancelled)
    }

    // MARK: - Finished

    @Test(arguments: [.character("a"), .character("i"), .backspace, .escape] as [HintKey])
    func `once a label is selected, every key is ignored`(key: HintKey) {
        var matcher = HintMatcher(labels: Self.labels)
        _ = matcher.handle(.character("d"))
        let before = matcher

        #expect(matcher.handle(key) == .ignored)
        #expect(matcher == before)
        #expect(matcher.phase == .selected("d"))
    }

    @Test(arguments: [.character("a"), .character("i"), .backspace, .escape] as [HintKey])
    func `once cancelled, every key is ignored`(key: HintKey) {
        var matcher = Self.narrowed()
        _ = matcher.handle(.escape)
        let before = matcher

        #expect(matcher.handle(key) == .ignored)
        #expect(matcher == before)
        #expect(matcher.phase == .cancelled)
    }

    @Test
    func `a finished matcher offers no candidates`() {
        var selected = HintMatcher(labels: Self.labels)
        _ = selected.handle(.character("a"))
        var cancelled = HintMatcher(labels: Self.labels)
        _ = cancelled.handle(.escape)

        #expect(selected.candidates.isEmpty)
        #expect(cancelled.candidates.isEmpty)
    }

    // MARK: - Edge cases

    @Test
    func `with no labels every character is ignored and escape still cancels`() {
        var matcher = HintMatcher(labels: [])

        #expect(matcher.candidates.isEmpty)
        #expect(matcher.handle(.character("a")) == .ignored)
        #expect(matcher.handle(.escape) == .cancelled)
    }

    @Test
    func `an exact match wins over a longer label sharing its prefix`() {
        var matcher = HintMatcher(labels: ["a", "ab"])

        #expect(matcher.handle(.character("a")) == .selected("a"))
    }

    @Test
    func `the matcher is a value: a copy does not see the original's keys`() {
        let original = HintMatcher(labels: Self.labels)
        var copy = original
        _ = copy.handle(.character("i"))

        #expect(original.typed.isEmpty)
        #expect(copy.typed == "i")
    }
}
