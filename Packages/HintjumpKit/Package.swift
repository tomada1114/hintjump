// swift-tools-version: 6.2
import PackageDescription

/// Strictness from day one: Swift 6 language mode (data-race safety as errors)
/// and every warning treated as an error. There is never a "legacy" codebase.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "HintjumpKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HintjumpCore", targets: ["HintjumpCore"]),
        .library(name: "HintjumpUI", targets: ["HintjumpUI"]),
        .library(name: "HintjumpPlatform", targets: ["HintjumpPlatform"]),
    ],
    targets: [
        .target(name: "HintjumpCore", swiftSettings: strictSettings),
        .target(name: "HintjumpUI", dependencies: ["HintjumpCore"], swiftSettings: strictSettings),
        // OS-integration adapters behind Core-declared ports. Depends on HintjumpCore
        // only: it must not see HintjumpUI, and HintjumpUI must not see it (enforced by
        // ArchitectureBoundaryTests, since SwiftPM cannot stop a system framework
        // import and this graph alone would not stop a later dependency edit).
        .target(
            name: "HintjumpPlatform",
            dependencies: ["HintjumpCore"],
            swiftSettings: strictSettings,
        ),
        .testTarget(
            name: "HintjumpCoreTests",
            dependencies: ["HintjumpCore"],
            swiftSettings: strictSettings,
        ),
        // Local-machine tests for the adapters: they talk to the real OS, which a CI
        // runner cannot (no logged-in GUI session, and no way to grant Accessibility,
        // Input Monitoring, or Screen Recording). Every suite here carries the
        // `.requiresLocalMachine` trait, so the tests are reported as skipped unless
        // RUN_LOCAL_MACHINE_TESTS=1 is set — `just test-local` sets it. Linking
        // HintjumpPlatform does not put it inside the coverage floor: scripts/coverage.sh
        // measures Sources/HintjumpCore and nothing else.
        // Off-screen rendering of the HintjumpUI views, compared with committed reference
        // images under References/ (excluded here: they are read and written by path, not
        // bundled). ImageRenderer needs no window, display, or TCC grant, so these run
        // under `just test` and in CI like any Core test.
        .testTarget(
            name: "HintjumpUITests",
            dependencies: ["HintjumpUI", "HintjumpCore"],
            exclude: ["References"],
            swiftSettings: strictSettings,
        ),
        .testTarget(
            name: "HintjumpPlatformTests",
            dependencies: ["HintjumpPlatform", "HintjumpCore"],
            swiftSettings: strictSettings,
        ),
    ],
)
