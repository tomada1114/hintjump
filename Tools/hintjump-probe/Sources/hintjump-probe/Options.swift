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
    /// How many reads `time` makes when `--runs` is not given.
    static let defaultRuns = 10

    let command: Command
    let bundleIdentifier: String
    let scope: ReadScope
    let strategy: ReadStrategy
    let runs: Int

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

        var parsedApp: String?
        var parsedScope = ReadScope.focusedWindow
        var parsedStrategy = ReadStrategy.naive
        var parsedRuns = defaultRuns

        var rest = arguments.dropFirst()
        while let flag = rest.first {
            rest = rest.dropFirst()
            switch flag {
            case "--app":
                parsedApp = try value(for: flag, from: &rest)

            case "--scope":
                parsedScope = try parseScope(value(for: flag, from: &rest))

            case "--strategy":
                parsedStrategy = try parseStrategy(value(for: flag, from: &rest))

            case "--runs":
                parsedRuns = try parseRuns(value(for: flag, from: &rest))

            default:
                throw ProbeError.unknownArgument(flag)
            }
        }

        guard let parsedApp else {
            throw ProbeError.missingValue("--app")
        }
        return Self(
            command: parsedCommand,
            bundleIdentifier: parsedApp,
            scope: parsedScope,
            strategy: parsedStrategy,
            runs: parsedRuns,
        )
    }

    private static func value(
        for flag: String,
        from rest: inout ArraySlice<String>,
    ) throws -> String {
        guard let next = rest.first, !next.hasPrefix("--") else {
            throw ProbeError.missingValue(flag)
        }
        rest = rest.dropFirst()
        return next
    }

    /// Accepts the port's own spellings and the short ones the issue writes.
    private static func parseScope(_ raw: String) throws -> ReadScope {
        switch raw.lowercased() {
        case "app", "application":
            .application

        case "focused", "focusedwindow":
            .focusedWindow

        case "menubar":
            .menuBar

        default:
            throw ProbeError.unknownValue(flag: "--scope", value: raw)
        }
    }

    private static func parseStrategy(_ raw: String) throws -> ReadStrategy {
        let match = ReadStrategy.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
        guard let match else {
            throw ProbeError.unknownValue(flag: "--strategy", value: raw)
        }
        return match
    }

    private static func parseRuns(_ raw: String) throws -> Int {
        guard let parsed = Int(raw), parsed > 0 else {
            throw ProbeError.unknownValue(flag: "--runs", value: raw)
        }
        return parsed
    }
}
