import AppKit
import HintjumpCore
import HintjumpPlatform

/// The percentile `time` reports alongside the median, and the halves a median is made
/// of — named because a bare `0.95` or `2` in the arithmetic below says nothing.
private let tailPercentile = 0.95
private let halves = 2

/// Runs one parsed command line against the real adapter.
///
/// Synchronous throughout: the port is `@MainActor`, top-level code in Swift 6 is
/// `@MainActor` too, so a probe that never suspends never has to reason about when the
/// tree it read stopped being true.
@MainActor
func run(_ options: Options) throws {
    let reader = AXUIElementTreeReader()

    switch options.command {
    case .dump:
        try dump(with: reader, pid: processIdentifier(for: options), options: options)

    case .front:
        // `front` resolves its own application: the frontmost one when `--app` is
        // absent, and afresh on every sample of a watch.
        try front(with: reader, options: options)

    case .time:
        try time(with: reader, pid: processIdentifier(for: options), options: options)

    case .wake:
        let pid = try processIdentifier(for: options)
        try wake(with: reader, pid: pid)
        try dump(with: reader, pid: pid, options: options)
    }
}

/// Asks the application to build its tree, then dumps it either way.
///
/// An application that does not watch for `AXManualAccessibility` reports it as
/// unsupported, which is an answer and not a failure — Finder needs no waking. It is
/// said on stderr and the dump goes ahead, so `wake` and `dump` can be compared on any
/// application, which is the whole point of the Electron verification.
@MainActor
func wake(with reader: AXUIElementTreeReader, pid: pid_t) throws {
    do {
        try reader.enableManualAccessibility(pid: pid)
    } catch let error as AccessibilityReadError {
        guard case .attributeUnsupported = error else { throw error }
        printError(describe(error))
    }
}

/// The pid of the first running instance of `--app`.
@MainActor
func processIdentifier(for options: Options) throws -> pid_t {
    let bundleIdentifier = try options.requiredBundleIdentifier()
    let running = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleIdentifier,
    )
    guard let application = running.first else {
        throw ProbeError.notRunning(bundleIdentifier)
    }
    return application.processIdentifier
}

@MainActor
func dump(with reader: AXUIElementTreeReader, pid: pid_t, options: Options) throws {
    let tree = try reader.readTree(pid: pid, scope: options.scope, strategy: options.strategy)
    let ranking = options.rank ? Ranking(tree.elements) : nil
    for (index, element) in tree.elements.enumerated() {
        let extra = ranking?.fields(forElementAt: index) ?? []
        print(row(index: index, element: element, extra: extra))
    }
    print(summary(of: tree))
    if let ranking {
        print(ranking.summary)
    }
}

/// Reads `options.runs` times and reports the shape of the distribution.
///
/// p95 is the value at `ceil(0.95 * n) - 1` of the sorted durations — the nearest-rank
/// definition, which needs no interpolation and is honest about a small `n`: with the
/// default ten runs it is simply the slowest read.
@MainActor
func time(with reader: AXUIElementTreeReader, pid: pid_t, options: Options) throws {
    var durations: [Double] = []
    var elements = 0
    for _ in 0 ..< options.runs {
        let tree = try reader.readTree(pid: pid, scope: options.scope, strategy: options.strategy)
        durations.append(tree.readDuration.milliseconds)
        elements = tree.elements.count
    }

    let sorted = durations.sorted()
    let rank = Int((tailPercentile * Double(sorted.count)).rounded(.up)) - 1
    let tail = sorted[min(max(rank, 0), sorted.count - 1)]
    print(
        "p50=\(formatted(median(of: sorted)))ms p95=\(formatted(tail))ms "
            + "runs=\(options.runs) elements=\(elements) "
            + "scope=\(options.scope.rawValue) strategy=\(options.strategy.rawValue)",
    )
}

/// The median of an already sorted, non-empty list.
func median(of sorted: [Double]) -> Double {
    let middle = sorted.count / halves
    if sorted.count.isMultiple(of: halves) {
        return (sorted[middle - 1] + sorted[middle]) / Double(halves)
    }
    return sorted[middle]
}
