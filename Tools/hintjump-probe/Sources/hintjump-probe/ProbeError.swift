import HintjumpCore

/// The exit code for a command line this tool could not make sense of (`EX_USAGE`),
/// so a shell script can tell a typo from a read that genuinely could not happen.
let usageExitCode: Int32 = 64
/// The exit code for everything else that failed.
let failureExitCode: Int32 = 1

/// Everything the probe can refuse to do, with the sentence it prints on stderr.
enum ProbeError: Error {
    case inapplicable(flag: String, command: Command)
    case missingValue(String)
    case notRunning(String)
    case unknownArgument(String)
    case unknownValue(flag: String, value: String)
    case usage

    /// `usageExitCode` for a mistyped command line, `failureExitCode` for a real one.
    var exitCode: Int32 {
        switch self {
        case .notRunning:
            failureExitCode

        case .inapplicable, .missingValue, .unknownArgument, .unknownValue, .usage:
            usageExitCode
        }
    }

    /// Everything to print: the complaint, and the usage text when the complaint is
    /// about how the tool was called.
    var message: String {
        switch self {
        case let .inapplicable(flag, command):
            "\(flag) does not apply to \(command.rawValue).\n\n\(usageText)"

        case let .missingValue(flag):
            "\(flag) needs a value.\n\n\(usageText)"

        case let .notRunning(bundleIdentifier):
            "No running application with bundle identifier \(bundleIdentifier)."

        case let .unknownArgument(argument):
            "Unknown argument \(argument).\n\n\(usageText)"

        case let .unknownValue(flag, value):
            "\(flag) does not accept \(value).\n\n\(usageText)"

        case .usage:
            usageText
        }
    }
}

/// What a caller reads from `--help`, from a bare invocation, and from a typo.
let usageText = """
usage: hintjump-probe <command> --app <bundle-id> [options]

commands:
    dump   print every element of the tree, then its count and read duration
    time   read repeatedly and print p50/p95 of the read duration
    front  print the application's direct children, then its focused-window root
    wake   set AXManualAccessibility on the application, then dump

options:
    --app <bundle-id>  the running application to read (required)
    --scope <scope>    focusedWindow (default), menuBar, or application
    --strategy <name>  naive (default), batched, pruned, or batchedPruned
    --runs <n>         reads for `time` (default \(Options.defaultRuns))
    --rank             with dump or wake: each element's rank, or why it is not a target

`--scope` also accepts the short spellings focused, menubar, and app.

Reading another application's tree needs the Accessibility permission, which macOS
holds against the process: grant it to the terminal that launches this tool, in
System Settings > Privacy & Security > Accessibility.
"""

/// The sentence printed for a failed read, naming the case the port reported.
func describe(_ error: AccessibilityReadError) -> String {
    switch error {
    case let .attributeUnsupported(attribute):
        "attribute unsupported: the application answers nothing for \(attribute)."

    case let .failed(code):
        "failed: the Accessibility API returned AXError \(code)."

    case let .noSuchProcess(pid):
        "no such process: nothing is running as pid \(pid) any more."

    case .notTrusted:
        """
        not trusted: grant Accessibility to the terminal that launched this tool in \
        System Settings > Privacy & Security.
        """
    }
}
