import HintjumpCore

/// One dump's ranking under `--rank`: the ranker's answer for every element, rendered
/// as row fields and a closing count.
///
/// The ranking itself is Core's (`TargetRanker` with its first-cut tiers); this only
/// prints it, so what the target-count measurement records is what the app will do.
struct Ranking {
    private let targets: [RankedTarget]
    private let exclusions: [TargetExclusion?]
    private let targetsByElementIndex: [Int: RankedTarget]

    /// The line after the dump's summary: how many targets, and how many per tier.
    var summary: String {
        let perTier = TargetTier.allCases.sorted().map { tier in
            "tier\(tier.rawValue)=\(targets.count { $0.tier == tier })"
        }
        return (["targets=\(targets.count)"] + perTier).joined(separator: " ")
    }

    init(_ elements: [ElementSnapshot]) {
        let ranking = TargetRanker().ranking(elements)
        targets = ranking.targets
        exclusions = ranking.exclusions
        targetsByElementIndex = Dictionary(
            uniqueKeysWithValues: targets.map { ($0.elementIndex, $0) },
        )
    }

    /// `rank=N tier=T` for a target, or `rank=- excluded=<reason>` for anything else —
    /// so `grep 'rank=[0-9]'` lists the targets and `grep excluded=tooSmall` a reason,
    /// a dropped duplicate (`sameFrame`, `insideTargetControl`, `insideTargetRow`,
    /// `underColumnHeader`, `windowSizedGroup`) included.
    func fields(forElementAt index: Int) -> [String] {
        if let target = targetsByElementIndex[index] {
            return ["rank=\(target.rank)", "tier=\(target.tier.rawValue)"]
        }
        let reason = exclusions[index]
        return ["rank=-", "excluded=\(reason?.rawValue ?? "-")"]
    }
}
