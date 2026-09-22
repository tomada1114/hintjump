import Foundation
import HintjumpCore

/// The probe's entry point: parse, run, and turn any failure into a sentence on stderr
/// and an exit code. Results go to stdout, diagnostics to stderr, so `dump | grep` sees
/// only elements.
let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    printError(usageText)
    exit(usageExitCode)
}

do {
    try run(Options.parse(arguments))
} catch let error as ProbeError {
    printError(error.message)
    exit(error.exitCode)
} catch let error as AccessibilityReadError {
    printError(describe(error))
    exit(failureExitCode)
} catch {
    printError("\(error)")
    exit(failureExitCode)
}
