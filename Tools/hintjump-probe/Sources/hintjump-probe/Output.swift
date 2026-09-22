import Foundation
import HintjumpCore

/// A millisecond count with two decimals, so two strategies can be compared by eye.
func formatted(_ milliseconds: Double) -> String {
    String(format: "%.2f", milliseconds)
}

/// One element as one greppable line.
///
/// Every field is `name=value` rather than a fixed-width column, so `grep actions=` and
/// `grep 'role=AXButton'` both work and a long title cannot push a later column out of
/// alignment. `-` means the application answered nothing for that attribute. The depth
/// is a column rather than indentation, for the same reason. `extra` fields — the rank,
/// under `--rank` — go right after the index, so they stay on the row's first line.
func row(index: Int, element: ElementSnapshot, extra: [String]) -> String {
    let fields = ["#\(index)"] + extra + [
        "depth=\(element.depth)",
        "parent=\(element.parentIndex.map(String.init) ?? "-")",
        "role=\(element.role ?? "-")",
        "subrole=\(element.subrole ?? "-")",
        "enabled=\(element.isEnabled)",
        "frame=\(formatted(element.frame))",
        "actions=\(element.actions.isEmpty ? "-" : element.actions.joined(separator: ","))",
        "title=\(quoted(element.title))",
        "description=\(quoted(element.description))",
    ]
    return fields.joined(separator: " ")
}

/// `x,y,w,h` as integers, or `-` for an element with no position or size.
func formatted(_ frame: CGRect?) -> String {
    guard let frame else {
        return "-"
    }
    let parts = [frame.minX, frame.minY, frame.width, frame.height]
    return parts.map { String(format: "%.0f", $0) }.joined(separator: ",")
}

/// A title or description, quoted so an empty one is visible, and `-` for a missing one.
func quoted(_ text: String?) -> String {
    guard let text else {
        return "-"
    }
    return "\"\(text)\""
}

/// The line that closes a `dump`.
func summary(of tree: TreeSnapshot) -> String {
    """
    elements=\(tree.elements.count) duration=\(formatted(tree.readDuration.milliseconds))ms \
    scope=\(tree.scope.rawValue) strategy=\(tree.strategy.rawValue)
    """
}

/// Writes one line to stderr, where every diagnostic this tool prints belongs: stdout
/// carries results a caller may pipe into something else.
func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
