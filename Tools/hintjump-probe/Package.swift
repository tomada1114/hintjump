// swift-tools-version: 6.2
import PackageDescription

/// The same strictness as `Packages/HintjumpKit/Package.swift`: Swift 6 language mode
/// and every warning an error. A probe is still real code, and it links the real
/// adapter — nothing here is allowed to compile under looser rules than what it calls.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

/// A separate package on purpose, outside `Packages/`: this tool exists to print, and
/// `.swiftlint.yml`'s `no_print_in_sources` rightly bans `print` under
/// `Packages/*/Sources/`. It is never linked by the app — `project.yml` does not know
/// it exists — and depends on HintjumpKit by path so it always builds the working copy.
let package = Package(
    name: "hintjump-probe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/HintjumpKit"),
    ],
    targets: [
        .executableTarget(
            name: "hintjump-probe",
            dependencies: [
                .product(name: "HintjumpCore", package: "HintjumpKit"),
                .product(name: "HintjumpPlatform", package: "HintjumpKit"),
            ],
            swiftSettings: strictSettings,
        ),
    ],
)
