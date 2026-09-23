import HintjumpCore

/// What the probe was asked to do.
enum Command: String, CaseIterable {
    case dump
    case front
    case time
    case wake
}

/// A parsed command line.
struct Options {
    /// `front --watch`: how long to sample, and how often.
    struct Watch: Equatable {
        let duration: Duration
        let interval: Duration
    }

    /// Everything the flags set, before the checks that need all of them at once.
    private struct Draft {
        var app: String?
        var scope = ReadScope.focusedWindow
        var strategy = ReadStrategy.naive
        var runs = Options.defaultRuns
        var rank = false
        var watchSeconds: Int?
        var intervalMilliseconds: Int?

        mutating func apply(_ flag: String, from rest: inout ArraySlice<String>) throws {
            switch flag {
            case "--app":
                app = try value(for: flag, from: &rest)

            case "--scope":
                scope = try parseScope(value(for: flag, from: &rest))

            case "--strategy":
                strategy = try parseStrategy(value(for: flag, from: &rest))

            case "--runs":
                runs = try parsePositive(flag, value(for: flag, from: &rest))

            case "--rank":
                rank = true

            case "--watch":
                watchSeconds = try parsePositive(flag, value(for: flag, from: &rest))

            case "--interval":
                intervalMilliseconds = try parsePositive(flag, value(for: flag, from: &rest))

            default:
                throw ProbeError.unknownArgument(flag)
            }
        }
    }

    /// How many reads `time` makes when `--runs` is not given.
    static let defaultRuns = 10
    /// How often `front --watch` samples when `--interval` is not given, in milliseconds.
    static let defaultIntervalMilliseconds = 500
    /// The commands that print a dump, and so can print ranks in it.
    static let rankingCommands: Set<Command> = [.dump, .wake]

    let command: Command
    /// `nil` only for `front`, which then reads whichever application is frontmost.
    let bundleIdentifier: String?
    let scope: ReadScope
    let strategy: ReadStrategy
    let runs: Int
    /// Whether `dump` (and `wake`, which dumps) adds each element's rank to its row.
    let rank: Bool
    /// `front --watch`, or `nil` for a single snapshot.
    let watch: Watch?

    /// Parses the arguments after the executable name.
    ///
    /// Hand-rolled rather than argument-parser-backed: this package would otherwise be
    /// the repository's first dependency, and `.claude/rules/project.md`'s Dependency
    /// Policy asks a harder question than a four-subcommand probe can answer.
    static func parse(_ arguments: [String]) throws -> Self {
        guard let first = arguments.first, !first.hasPrefix("-") else {
            throw ProbeError.usage
        }
        guard let parsedCommand = Command(rawValue: first) else {
            throw ProbeError.unknownArgument(first)
        }

        var draft = Draft()
        var rest = arguments.dropFirst()
        while let flag = rest.first {
            rest = rest.dropFirst()
            try draft.apply(flag, from: &rest)
        }

        // `front` alone may go without `--app`: it then follows the frontmost application,
        // which is the only way one watch can see Finder, Spotlight, and Control Center.
        guard draft.app != nil || parsedCommand == .front else {
            throw ProbeError.missingValue("--app")
        }
        try check(draft, appliesTo: parsedCommand)
        return Self(
            command: parsedCommand,
            bundleIdentifier: draft.app,
            scope: draft.scope,
            strategy: draft.strategy,
            runs: draft.runs,
            rank: draft.rank,
            watch: draft.watchSeconds.map { seconds in
                Watch(
                    duration: .seconds(seconds),
                    interval: .milliseconds(draft
                        .intervalMilliseconds ?? defaultIntervalMilliseconds),
                )
            },
        )
    }

    /// A flag that changes what a command prints is refused on a command that would
    /// ignore it, rather than silently ignored: `--rank` without a dump, `--watch` on
    /// anything but `front`, and `--interval` without `--watch`.
    private static func check(_ draft: Draft, appliesTo command: Command) throws {
        guard !draft.rank || rankingCommands.contains(command) else {
            throw ProbeError.inapplicable(flag: "--rank", command: command)
        }
        guard draft.watchSeconds == nil || command == .front else {
            throw ProbeError.inapplicable(flag: "--watch", command: command)
        }
        guard draft.intervalMilliseconds == nil || draft.watchSeconds != nil else {
            throw ProbeError.needs(flag: "--interval", other: "--watch")
        }
    }

    /// The bundle identifier every command but `front` requires, which `parse` has
    /// already guaranteed for them.
    func requiredBundleIdentifier() throws -> String {
        guard let bundleIdentifier else {
            throw ProbeError.missingValue("--app")
        }
        return bundleIdentifier
    }
}

/// Parsing one flag's value.
private func value(for flag: String, from rest: inout ArraySlice<String>) throws -> String {
    guard let next = rest.first, !next.hasPrefix("--") else {
        throw ProbeError.missingValue(flag)
    }
    rest = rest.dropFirst()
    return next
}

/// Accepts the port's own spellings and the short ones the issue writes.
private func parseScope(_ raw: String) throws -> ReadScope {
    switch raw.lowercased() {
    case "app", "application":
        .application

    case "focused", "focusedwindow":
        .focusedWindow

    case "menubar":
        .menuBar

    case "popup", "popupmenu":
        .popUpMenu

    default:
        throw ProbeError.unknownValue(flag: "--scope", value: raw)
    }
}

private func parseStrategy(_ raw: String) throws -> ReadStrategy {
    let match = ReadStrategy.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
    guard let match else {
        throw ProbeError.unknownValue(flag: "--strategy", value: raw)
    }
    return match
}

/// A whole number above zero: a run count, a watch's seconds, an interval's milliseconds.
private func parsePositive(_ flag: String, _ raw: String) throws -> Int {
    guard let parsed = Int(raw), parsed > 0 else {
        throw ProbeError.unknownValue(flag: flag, value: raw)
    }
    return parsed
}
