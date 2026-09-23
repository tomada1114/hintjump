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
    case needs(flag: String, other: String)
    case noFrontmostApplication
    case notRunning(String)
    case unknownArgument(String)
    case unknownValue(flag: String, value: String)
    case usage

    /// `usageExitCode` for a mistyped command line, `failureExitCode` for a real one.
    var exitCode: Int32 {
        switch self {
        case .noFrontmostApplication, .notRunning:
            failureExitCode

        case .inapplicable, .missingValue, .needs, .unknownArgument, .unknownValue, .usage:
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

        case let .needs(flag, other):
            "\(flag) needs \(other).\n\n\(usageText)"

        case .noFrontmostApplication:
            "No application is frontmost; name one with --app."

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
usage: hintjump-probe front [--app <bundle-id>] [--watch <seconds> [--interval <ms>]]

commands:
    dump   print every element of the tree, then its count and read duration
    time   read repeatedly and print p50/p95 of the read duration
    front  print the application's direct children and focused-window root, then a
        snapshot of what is on top: the focused window and every AXWindows entry with
        its subrole, selected menu bar items, open menus, every on-screen window above
        the normal layer (layer, bounds, owner pid and name), and each container
        (window, sheet, popover, drawer, menu) with its clickable count, in the
        frontmost application and in any other application that owns such a window
        outside the menu bar strip
    wake   set AXManualAccessibility on the application, then dump

options:
    --app <bundle-id>  the running application to read (required, except for front,
        which otherwise reads whichever application is frontmost)
    --scope <scope>    focusedWindow (default), menuBar, application, or popUpMenu (the
        menu open in the application's frontmost pop-up-menu-level window: a context menu)
    --strategy <name>  naive (default), batched, pruned, or batchedPruned
    --runs <n>         reads for `time` (default \(Options.defaultRuns))
    --rank             with dump or wake: each element's rank, or why it is not a target
    --watch <seconds>  with front: sample for this long and print a snapshot each time
        the signals change; without --app it follows the frontmost application. It
        only reads: it never clicks, types, or activates anything
    --interval <ms>    with --watch: time between samples (default \(Options
    .defaultIntervalMilliseconds))

`--scope` also accepts the short spellings focused, menubar, app, and popup.

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
