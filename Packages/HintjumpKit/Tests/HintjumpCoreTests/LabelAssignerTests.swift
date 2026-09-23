import CoreGraphics
import HintjumpCore
import Testing

@Suite("LabelAssigner")
struct LabelAssignerTests {
    /// The default hint character set (`docs/decisions.md` › "Default triggers and
    /// default hint characters").
    static let characters = Array("asdfghjklqwertyuiopzxcvbnm")
    /// The characters the default set leaves for two-character prefixes once the first
    /// 16 are singles.
    static let prefixes = Array("iopzxcvbnm")
    /// Single counts around the set's bounds: whatever the count, the singles give way
    /// once they would leave targets unlabeled, so every one reaches 26 × 26.
    static let singleCounts = [0, 1, 25, 26, 40]

    let assigner = LabelAssigner()

    // MARK: - Capacity

    @Test
    func `the default assigner hands out 16 singles`() {
        #expect(LabelAssigner.defaultSingleCount == 16)
        #expect(assigner.singleCount == 16)
    }

    @Test
    func `with 26 characters and 16 singles there are 260 pairs`() {
        let labels = assigner.labels(count: 276, characters: Self.characters)

        #expect(labels.count == 276)
        #expect(labels.count { $0.count == 1 } == 16)
        #expect(labels.count { $0.count == 2 } == 260)
        #expect(Set(labels).count == labels.count)
    }

    @Test(arguments: singleCounts)
    func `capacity is every character a prefix, whatever the single count`(singleCount: Int) {
        let custom = LabelAssigner(singleCount: singleCount)

        #expect(custom.capacity(characters: Self.characters) == 676)
        #expect(custom.labels(count: 1_000, characters: Self.characters).count == 676)
    }

    @Test
    func `a negative single count is treated as zero`() {
        let custom = LabelAssigner(singleCount: -3)

        #expect(custom.singleCount == 0)
        #expect(custom.labels(count: 2, characters: Self.characters) == ["aa", "as"])
    }

    @Test
    func `a set smaller than the single count makes every character a single`() {
        let small = Array("asdfghjk")
        let labels = assigner.labels(count: 8, characters: small)

        #expect(labels == small.map { String($0) })
    }

    // MARK: - Partition and order

    @Test
    func `no two-character label starts with a single's letter`() {
        let labels = assigner.labels(count: 276, characters: Self.characters)
        let singles = Set(labels.filter { $0.count == 1 }.compactMap(\.first))
        let pairStarts = Set(labels.filter { $0.count == 2 }.compactMap(\.first))

        #expect(singles.isDisjoint(with: pairStarts))
        #expect(pairStarts == Set(Self.prefixes))
    }

    @Test
    func `no label is a prefix of another`() {
        let labels = assigner.labels(count: 276, characters: Self.characters)

        for label in labels {
            #expect(!labels.contains { $0 != label && $0.hasPrefix(label) })
        }
    }

    @Test
    func `singles follow the character set's order`() {
        let labels = assigner.labels(count: 16, characters: Self.characters)

        #expect(labels == "asdfghjklqwertyu".map { String($0) })
    }

    @Test
    func `pairs run through the full set under each prefix in turn`() {
        let pairs = Array(assigner.labels(count: 276, characters: Self.characters).dropFirst(16))

        #expect(pairs.prefix(3) == ["ia", "is", "id"])
        #expect(pairs[25] == "im")
        #expect(pairs[26] == "oa")
        #expect(pairs.last == "mm")
    }

    @Test(arguments: [0, 1, 5, 15, 16])
    func `up to the single count every target is a single`(count: Int) {
        let labels = assigner.labels(count: count, characters: Self.characters)

        #expect(labels.count == count)
        #expect(labels.allSatisfy { $0.count == 1 })
    }

    @Test
    func `a negative count gives no labels`() {
        #expect(assigner.labels(count: -1, characters: Self.characters).isEmpty)
    }

    @Test
    func `the first target past the singles gets the first pair`() {
        let labels = assigner.labels(count: 17, characters: Self.characters)

        #expect(labels.last == "ia")
    }

    @Test
    func `a repeated character is used once, where it first appears`() {
        let labels = LabelAssigner(singleCount: 2).labels(count: 5, characters: Array("aasd"))

        #expect(labels == ["a", "s", "da", "ds", "dd"])
    }

    @Test
    func `no characters means no labels`() {
        #expect(assigner.capacity(characters: []) == 0)
        #expect(assigner.labels(count: 3, characters: []).isEmpty)
    }

    // MARK: - Assigning targets

    @Test
    func `each target gets the label at its rank`() {
        let targets = Array(100 ..< 120)
        let assignment = assigner.assign(targets, characters: Self.characters)

        #expect(assignment.labeled.map(\.target) == targets)
        #expect(assignment.labels == assigner.labels(count: 20, characters: Self.characters))
        #expect(assignment.labeled[0] == LabeledTarget(label: "a", target: 100))
        #expect(assignment.labeled[16] == LabeledTarget(label: "ia", target: 116))
        #expect(assignment.unlabeled.isEmpty)
        #expect(assignment.unlabeledCount == 0)
    }

    @Test
    func `fewer targets than the single count all get singles`() {
        let assignment = assigner.assign([1, 2, 3], characters: Self.characters)

        #expect(assignment.labels == ["a", "s", "d"])
    }

    @Test
    func `no targets gives an empty assignment`() {
        let assignment = assigner.assign([Int](), characters: Self.characters)

        #expect(assignment.labeled.isEmpty)
        #expect(assignment.unlabeledCount == 0)
    }

    @Test
    func `targets past the supply are left unlabeled and counted, in rank order`() {
        let targets = Array(0 ..< 680)
        let assignment = assigner.assign(targets, characters: Self.characters)

        #expect(assignment.labeled.count == 676)
        #expect(assignment.labeled.first == LabeledTarget(label: "aa", target: 0))
        #expect(assignment.labeled.last == LabeledTarget(label: "mm", target: 675))
        #expect(assignment.unlabeled == [676, 677, 678, 679])
        #expect(assignment.unlabeledCount == 4)
    }

    @Test
    func `the same input always gives the same assignment`() {
        let targets = Array(0 ..< 300)

        let first = assigner.assign(targets, characters: Self.characters)
        let second = assigner.assign(targets, characters: Self.characters)

        #expect(first == second)
    }

    @Test
    func `a label finds its target, and an unknown one finds nothing`() {
        let assignment = assigner.assign(Array(0 ..< 30), characters: Self.characters)

        #expect(assignment.target(labeled: "a") == 0)
        #expect(assignment.target(labeled: "is") == 17)
        #expect(assignment.target(labeled: "zz") == nil)
        #expect(assignment.target(labeled: "") == nil)
    }

    @Test
    func `the ranker's output is labeled in rank order`() throws {
        let buttons = (0 ..< 3).map { column in
            ElementSnapshot(
                role: "AXButton",
                subrole: nil,
                title: nil,
                description: nil,
                frame: CGRect(x: 10 + 50 * column, y: 10, width: 40, height: 20),
                isEnabled: true,
                actions: ["AXPress"],
                depth: 1,
                parentIndex: 0,
            )
        }
        let window = ElementSnapshot(
            role: "AXWindow",
            subrole: "AXStandardWindow",
            title: nil,
            description: nil,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        let ranked = TargetRanker().rank([window] + buttons)

        let assignment = assigner.assign(ranked, characters: Self.characters)

        #expect(assignment.labels == ["a", "s", "d"])
        let first = try #require(assignment.target(labeled: "a"))
        #expect(first.rank == 1)
        #expect(assignment.labeled.map(\.target) == ranked)
    }
}
