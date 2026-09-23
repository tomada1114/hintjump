import AppKit
import HintjumpCore
import HintjumpPlatform

/// `front`: what is on top of the frontmost application, once or as a watch.
///
/// Reads only. Nothing here posts an event, activates or raises an application, or
/// moves the pointer, so a watch can run while a person opens menus and panels by hand
/// and what it records is what they did, not what the probe caused.
@MainActor
func front(with reader: AXUIElementTreeReader, options: Options) throws {
    guard AXIsProcessTrusted() else {
        throw AccessibilityReadError.notTrusted
    }
    AXRaw.limitMessagingTimeout()
    if let watch = options.watch {
        run(watch, with: reader, bundleIdentifier: options.bundleIdentifier)
        return
    }

    guard let target = FrontTarget.resolve(bundleIdentifier: options.bundleIdentifier) else {
        let missing = options.bundleIdentifier.map(ProbeError.notRunning)
        throw missing ?? ProbeError.noFrontmostApplication
    }
    try applicationChildren(with: reader, pid: target.pid)
    let clock = ContinuousClock()
    let start = clock.now
    let signals = FrontSignals.read(target)
    let signatureRead = clock.now - start
    printSnapshot(signals, reader: reader, heading: "snapshot \(timing(signatureRead))")
}

/// The baseline `front` printed before #9: the application's direct children — its
/// windows, panels, and menu bar — then the root a `.focusedWindow` read starts from.
@MainActor
func applicationChildren(with reader: AXUIElementTreeReader, pid: pid_t) throws {
    let tree = try reader.readTree(pid: pid, scope: .application, strategy: .naive)
    for (index, element) in tree.elements.enumerated() where element.depth == 1 {
        print(row(index: index, element: element, extra: []))
    }
    print(summary(of: tree))

    do {
        let focused = try reader.readTree(pid: pid, scope: .focusedWindow, strategy: .naive)
        guard let root = focused.elements.first else {
            print("no focused window")
            return
        }
        print("focusedWindow " + row(index: 0, element: root, extra: []))
    } catch let error as AccessibilityReadError {
        guard case .attributeUnsupported = error else { throw error }
        print("no focused window")
    }
}

/// Samples the signals every `watch.interval` for `watch.duration`, and prints a full
/// snapshot only when their signature changes — so a five-minute session in which a
/// person opens ten things yields about ten snapshots, not six hundred.
///
/// The wait is the main run loop's, not a sleep: `NSWorkspace` learns which
/// application is frontmost from notifications delivered on that run loop, and a
/// command-line tool that never runs it keeps answering with the application that was
/// frontmost at launch. A timer covering the whole watch keeps the run loop from
/// returning early for want of a source.
@MainActor
func run(_ watch: Options.Watch, with reader: AXUIElementTreeReader, bundleIdentifier: String?) {
    let clock = ContinuousClock()
    let start = clock.now
    let deadline = start + watch.duration
    let keepAlive = Timer(timeInterval: watch.duration / .seconds(1) + 1, repeats: false) { _ in
        // Only a source for the run loop to wait on; the loop below does the work.
    }
    RunLoop.main.add(keepAlive, forMode: .default)
    defer { keepAlive.invalidate() }

    print("watch duration=\(seconds(watch.duration))s interval=\(watch.interval.milliseconds)ms "
        + "app=\(bundleIdentifier ?? "frontmost")")
    var last: String?
    var signatureReads: [Double] = []
    var snapshots = 0
    while clock.now < deadline {
        let tick = clock.now
        let signals = FrontSignals.read(FrontTarget.resolve(bundleIdentifier: bundleIdentifier))
        let signatureRead = clock.now - tick
        signatureReads.append(signatureRead.milliseconds)
        if signals.signature != last {
            last = signals.signature
            snapshots += 1
            let now = Date.now.ISO8601Format(.init(timeZone: .current))
            let heading = "snapshot t=\(seconds(tick - start))s at=\(now) \(timing(signatureRead))"
            printSnapshot(signals, reader: reader, heading: heading)
            fflush(nil)
        }
        RunLoop.main.run(until: Date.now.addingTimeInterval(watch.interval / .seconds(1)))
    }
    let sorted = signatureReads.sorted()
    print("watch done samples=\(sorted.count) snapshots=\(snapshots) "
        + "signatureRead p50=\(formatted(sorted.isEmpty ? 0 : median(of: sorted)))ms "
        + "max=\(formatted(sorted.last ?? 0))ms")
    fflush(nil)
}

/// Everything `front` knows about one instant, closing with what the snapshot cost.
///
/// The containers — and their clickable counts — come from a `.batchedPruned`
/// application read, the strategy the app itself reads with; any process that owns a
/// window above the normal layer outside the menu bar strip is read the same way, so a
/// panel Control Center or Spotlight draws is listed with its own pid.
@MainActor
func printSnapshot(_ signals: FrontSignals, reader: AXUIElementTreeReader, heading: String) {
    let clock = ContinuousClock()
    let start = clock.now
    print(heading)
    print("signature " + signals.signature)
    if let target = signals.target {
        printFrontmost(signals, target: target, reader: reader)
        printContainers(of: target.pid, reader: reader)
    } else {
        print("front none axFocusedApp=\(signals.axFocusedApplication.map(String.init) ?? "-")")
    }
    for window in signals.serverWindows {
        print(serverWindowLine(window))
    }
    for pid in otherProcesses(in: signals) {
        let application = AXUIElementCreateApplication(pid)
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        let focused = AXRaw.element(kAXFocusedWindowAttribute, of: application)
        print(
            "other pid=\(pid) bundle=\(bundle ?? "-") "
                + "focusedWindow=\(focused.map(AXRaw.roleAndSubrole) ?? "none")",
        )
        printMenus(MenuSignals.read(from: application), pid: pid)
        printContainers(of: pid, reader: reader)
    }
    print("snapshotRead=\(formatted((clock.now - start).milliseconds))ms")
}
