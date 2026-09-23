import HintjumpCore
import Testing

/// An assigner's single count, a target count, and the singles it keeps for them.
struct SingleBoundary: CustomTestStringConvertible {
    let singleCount: Int
    let count: Int
    let singles: Int

    var testDescription: String {
        "\(singleCount) singles at most, \(count) targets → \(singles) singles"
    }
}

extension LabelAssignerTests {
    /// Singles give way to prefixes only when keeping them all would leave targets
    /// unlabeled (`docs/decisions.md` › "The tier rule after #37's measurement; N stays
    /// 16").
    @Suite("adaptive singles")
    struct Adaptive {
        /// The labels 26 characters gave before singles could give way: the first 16
        /// characters as singles, then each of the other 10 followed by the whole set.
        static let sixteenSingleLabels: [String] = {
            let characters = LabelAssignerTests.characters
            let singles = characters.prefix(16).map { String($0) }
            let pairs = characters.dropFirst(16).flatMap { prefix in
                characters.map { String([prefix, $0]) }
            }
            return singles + pairs
        }()

        /// Target counts around each point where one more single would leave a target
        /// unlabeled, with the singles kept: `s + (26 − s) × 26` must reach the count.
        static let boundaries = [
            SingleBoundary(singleCount: 16, count: 276, singles: 16), // 16 + 10 × 26
            SingleBoundary(singleCount: 16, count: 277, singles: 15),
            SingleBoundary(singleCount: 16, count: 301, singles: 15), // 15 + 11 × 26
            SingleBoundary(singleCount: 16, count: 302, singles: 14),
            SingleBoundary(singleCount: 16, count: 651, singles: 1), // 1 + 25 × 26
            SingleBoundary(singleCount: 16, count: 652, singles: 0),
            SingleBoundary(singleCount: 16, count: 676, singles: 0), // 26 × 26
            SingleBoundary(singleCount: 25, count: 51, singles: 25), // 25 + 1 × 26
            SingleBoundary(singleCount: 25, count: 52, singles: 24),
            SingleBoundary(singleCount: 40, count: 26, singles: 26), // every character a single
            SingleBoundary(singleCount: 40, count: 27, singles: 25),
        ]

        let assigner = LabelAssigner()

        /// Whether the labels are distinct and none is a prefix of another, so a typed
        /// single can be acted on at once.
        static func isPrefixFree(_ labels: [String]) -> Bool {
            Set(labels).count == labels.count
                && labels.allSatisfy { label in
                    !labels.contains { $0 != label && $0.hasPrefix(label) }
                }
        }

        @Test(arguments: [0, 1, 15, 16, 17, 100, 275, 276])
        func `with 26 characters and up to 276 targets the labels are unchanged`(count: Int) {
            let labels = assigner.labels(count: count, characters: LabelAssignerTests.characters)

            #expect(labels == Array(Self.sixteenSingleLabels.prefix(count)))
        }

        @Test
        func `eight characters label forty targets`() {
            let labels = assigner.labels(count: 40, characters: Array("asdfghjk"))

            #expect(labels.count == 40)
            #expect(Self.isPrefixFree(labels))
            #expect(labels.count { $0.count == 1 } == 3) // 3 + 5 × 8 = 43
            #expect(labels.prefix(5) == ["a", "s", "d", "fa", "fs"])
            #expect(labels.last == "kg") // 37 pairs: 8 under each of f, g, h, j, then 5 under k
        }

        @Test
        func `eight characters leave no target of forty unlabeled`() {
            let assignment = assigner.assign(Array(0 ..< 40), characters: Array("asdfghjk"))

            #expect(assignment.labeled.count == 40)
            #expect(assignment.unlabeledCount == 0)
            #expect(assignment.target(labeled: "fa") == 3)
        }

        @Test
        func `with 26 characters 300 targets all get labels, with fewer than 16 singles`() {
            let labels = assigner.labels(count: 300, characters: LabelAssignerTests.characters)

            #expect(labels.count == 300)
            #expect(Self.isPrefixFree(labels))
            #expect(labels.count { $0.count == 1 } == 15)
            #expect(labels[15] == "ua")
        }

        @Test(arguments: boundaries)
        func `singles give way one at a time as the targets outgrow them`(boundary: SingleBoundary) {
            let labels = LabelAssigner(singleCount: boundary.singleCount)
                .labels(count: boundary.count, characters: LabelAssignerTests.characters)

            #expect(labels.count == boundary.count)
            #expect(labels.count { $0.count == 1 } == boundary.singles)
            #expect(Self.isPrefixFree(labels))
        }

        @Test(arguments: [("asdfghjk", 65), ("asdfghjk", 100), ("asdfghjklqwertyuiopzxcvbnm", 700)])
        func `more targets than every character as a prefix can label get that many`(
            characters: String,
            count: Int,
        ) {
            let size = characters.count
            let labels = assigner.labels(count: count, characters: Array(characters))

            #expect(assigner.capacity(characters: Array(characters)) == size * size)
            #expect(labels.count == size * size)
            #expect(labels.allSatisfy { $0.count == 2 })
            #expect(Self.isPrefixFree(labels))
        }

        @Test(arguments: [1, 2, 5])
        func `a one-character set keeps its single, whatever the count`(count: Int) {
            #expect(assigner.capacity(characters: ["a"]) == 1)
            #expect(assigner.labels(count: count, characters: ["a"]) == ["a"])
        }
    }
}
