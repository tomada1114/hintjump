/// Hands out hint labels to targets in rank order: single characters to the likeliest,
/// two characters to the rest, none once the supply runs out.
///
/// The rule is `docs/decisions.md` › "Single-character labels go to the likeliest
/// targets first": the first ``singleCount`` characters of the set are singles, and a
/// single's letter never starts a two-character label, so no label is a prefix of
/// another and a typed single can be acted on at once. The remaining characters are the
/// prefixes; each is followed by every character of the set, in set order, before the
/// next prefix starts. The same targets and characters always give the same labels.
///
/// ``singleCount`` is a ceiling: when that many singles would leave too few prefixes to
/// label every target — a short character set, or a window with many targets — singles
/// give way to prefixes one at a time, down to none (`docs/decisions.md` › "The tier
/// rule after #37's measurement; N stays 16"). While the full count covers the targets,
/// the labels are exactly the fixed-count ones.
///
/// Generic over the target so every entry point can use it: the frontmost window labels
/// ``RankedTarget``s (or what a session maps them to), the menu-bar entry points their
/// bar's items.
public struct LabelAssigner: Equatable, Sendable {
    /// N, the number of single-character labels, kept at 16 by the target-count
    /// measurement (`docs/decisions.md` › "The tier rule after #37's measurement; N stays
    /// 16").
    public static let defaultSingleCount = 16

    /// How many targets get a single-character label, never negative.
    public let singleCount: Int

    /// An assigner that gives `singleCount` targets a single (a negative count is zero).
    public init(singleCount: Int = defaultSingleCount) {
        self.singleCount = max(0, singleCount)
    }

    /// `characters` with each repeat after the first removed, order kept.
    private static func distinct(_ characters: [Character]) -> [Character] {
        var seen: Set<Character> = []
        return characters.filter { seen.insert($0).inserted }
    }

    /// How many of the first `size` characters are singles for `count` targets: the most,
    /// up to ``singleCount``, that still leave a label for every target, and otherwise
    /// the most that reach the set's whole supply of `size × size` labels.
    private func singles(forCount count: Int, alphabetSize size: Int) -> Int {
        let covered = min(count, size * size)
        return (0 ... min(singleCount, size)).last { $0 + (size - $0) * size >= covered } ?? 0
    }

    /// The most targets `characters` can label at once: every character a prefix,
    /// followed by every character. It does not depend on ``singleCount`` because
    /// ``labels(count:characters:)`` gives singles up to reach it; a repeated character
    /// counts once.
    public func capacity(characters: [Character]) -> Int {
        let size = Self.distinct(characters).count
        return size * size
    }

    /// Labels for `count` targets in hand-out order — as many singles as still leave a
    /// label for each — or ``capacity(characters:)`` labels when `count` exceeds it, and
    /// none when `count` is zero or negative.
    ///
    /// The list for one count is not a prefix of the list for a larger one once singles
    /// give way, so label the whole target list in one call. `characters` is used most
    /// preferred first; a repeated character is used once, where it first appears, so
    /// the labels stay distinct whatever the caller passes.
    public func labels(count: Int, characters: [Character]) -> [String] {
        let alphabet = Self.distinct(characters)
        let wanted = max(0, count)
        let singles = singles(forCount: wanted, alphabetSize: alphabet.count)
        var labels = alphabet.prefix(min(singles, wanted)).map { String($0) }
        for prefix in alphabet.dropFirst(singles) {
            for second in alphabet {
                guard labels.count < wanted else {
                    return labels
                }
                labels.append(String([prefix, second]))
            }
        }
        return labels
    }

    /// `targets`, in the order given (rank order), each with its label, and the ones
    /// past the supply left unlabeled.
    public func assign<Target>(
        _ targets: [Target],
        characters: [Character],
    ) -> LabelAssignment<Target> {
        let labels = labels(count: targets.count, characters: characters)
        let labeled = zip(labels, targets).map { label, target in
            LabeledTarget(label: label, target: target)
        }
        return LabelAssignment(labeled: labeled, unlabeled: Array(targets.dropFirst(labels.count)))
    }
}
