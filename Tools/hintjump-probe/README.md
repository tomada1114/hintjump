# hintjump-probe

A command-line probe for the first verifications this repository has to run — Electron
trees, read latency, the topmost container, and target counts — built on the same
`AccessibilityTreeReading` port and `AXUIElementTreeReader` adapter the app will use, so
what it measures is what the app will get. It is a separate SwiftPM package on purpose:
it lives outside `Packages/` because a probe exists to print and `.swiftlint.yml`'s
`no_print_in_sources` rightly bans `print` under `Packages/*/Sources/`, and it is never
linked by the app — `project.yml` does not know it exists. Reading another application's
accessibility tree needs the Accessibility permission, which macOS holds against the
*process*, so run it from a terminal that has been granted Accessibility in System
Settings › Privacy & Security; a terminal without it gets `not trusted` and nothing else.
Findings go under `docs/research/`, one file per verification.

Run it with `just probe <command> …`, or `swift run --package-path Tools/hintjump-probe
hintjump-probe <command> …`:

- `dump` — every element of the tree as one line each, then the count and the read
  duration: `just probe dump --app com.apple.finder --scope focusedWindow --strategy naive`.
  With `--rank` (also accepted by `wake`), each row also carries `HintjumpCore`'s
  `TargetRanker` verdict right after its index — `rank=N tier=T` for a target, or
  `rank=- excluded=<reason>` (`notClickable`, `disabled`, `noFrame`, `tooSmall`,
  `outsideWindow`) — and a last line counts the targets per tier:
  `just probe dump --app com.apple.finder --rank`. The root of the read bounds the
  targets, so rank a `focusedWindow` read; an `application` read's root has no frame and
  ranks nothing
- `time` — the same read repeated, reported as p50 and p95:
  `just probe time --app com.apple.finder --strategy batched --runs 10`
- `front` — the application's direct children (its windows, panels, and menu bar) and
  then its focused-window root: `just probe front --app com.apple.finder`
- `wake` — set `AXManualAccessibility` on the application, which is what Chromium and
  Electron applications wait for, and dump either way:
  `just probe wake --app com.microsoft.VSCode`
