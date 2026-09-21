import Foundation
import Testing

/// The second enforcement of the Core boundary (`AGENTS.md` › Architecture): `MyAppCore`
/// never imports a UI framework. `.swiftlint.yml`'s `no_ui_import_in_core` is the first;
/// this suite runs in the macOS `test` job, the lint rule in the `lint` job and the
/// pre-commit hook, so removing either one still leaves the other catching a regression.
@Suite("Architecture boundary")
struct ArchitectureBoundaryTests {
    /// UI frameworks `MyAppCore` must not import. `Cocoa` re-exports AppKit.
    ///
    /// Must match `.swiftlint.yml`'s `no_ui_import_in_core`: change both lists together.
    static let forbiddenModules = ["SwiftUI", "AppKit", "UIKit", "Cocoa"]

    /// The same pattern as the lint rule: any attributes (`@preconcurrency`, `@_exported`)
    /// and an optional kind keyword (`import struct SwiftUI.Color`) before the module.
    /// The `^\s*` anchor keeps a commented-out `// import SwiftUI` from matching.
    static let importPattern = #"^\s*(@[\w()]+\s+)*import\s+((typealias|struct|class|enum|protocol|let|var|func)\s+)?("#
        + forbiddenModules.joined(separator: "|")
        + #")\b"#

    /// `Sources/MyAppCore`, resolved from this file's path:
    /// `Tests/MyAppCoreTests/<this file>` up to the package root, then down.
    static let coreSourcesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("MyAppCore", isDirectory: true)

    // MARK: - Helpers

    /// The compiled ``importPattern``. Simple (ICU-style) word boundaries, as in the
    /// lint rule: Swift's default Unicode boundaries treat `SwiftUI.Color` as one
    /// word, so `\b` would never match after the module in a kind-qualified import.
    static func importRegex() throws -> Regex<AnyRegexOutput> {
        try Regex(importPattern).wordBoundaryKind(.simple)
    }

    /// Every `.swift` file under `directory`, recursively; empty if it does not exist.
    static func swiftFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
        ) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    // MARK: - The real Core sources

    @Test
    func `no MyAppCore source file imports a UI framework`() throws {
        let files = Self.swiftFiles(in: Self.coreSourcesDirectory)
        // A wrong path must fail here rather than pass on zero files.
        try #require(
            !files.isEmpty,
            "no .swift files found under \(Self.coreSourcesDirectory.path) — is the path resolution wrong?",
        )

        let regex = try Self.importRegex()
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() where line.firstMatch(of: regex) != nil {
                Issue.record("\(file.path):\(index + 1): UI framework import in MyAppCore: \(line)")
            }
        }
    }

    // MARK: - The pattern itself

    @Test(arguments: [
        "import SwiftUI",
        "import AppKit",
        "import UIKit",
        "import Cocoa",
        "  import SwiftUI",
        "@preconcurrency import AppKit",
        "@_exported import SwiftUI",
        "@testable @preconcurrency import UIKit",
        "import struct SwiftUI.Color",
        "import class AppKit.NSView",
        "import func Cocoa.NSApplicationMain",
    ])
    func `pattern matches every spelling of a UI framework import`(line: String) throws {
        let regex = try Self.importRegex()
        #expect(line.firstMatch(of: regex) != nil)
    }

    @Test(arguments: [
        "// import SwiftUI",
        "/// import AppKit",
        "import Foundation",
        "import Observation",
        "import SwiftUIExtras",
        "@preconcurrency import Combine",
        "let text = \"import SwiftUI\"",
    ])
    func `pattern ignores comments and other modules`(line: String) throws {
        let regex = try Self.importRegex()
        #expect(line.firstMatch(of: regex) == nil)
    }

    @Test
    func `file discovery finds nothing in a directory that does not exist`() {
        let missing = Self.coreSourcesDirectory.appendingPathComponent(
            "does-not-exist",
            isDirectory: true,
        )
        #expect(Self.swiftFiles(in: missing).isEmpty)
    }
}
