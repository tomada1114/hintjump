import AppKit
import HintjumpCore
import HintjumpPlatform

/// `12.3`: seconds with one decimal, precise enough to map a snapshot to a case.
func seconds(_ duration: Duration) -> String {
    String(format: "%.1f", duration / .seconds(1))
}

/// `signatureRead=1.23ms`: what reading the signals alone cost.
func timing(_ signatureRead: Duration) -> String {
    "signatureRead=\(formatted(signatureRead.milliseconds))ms"
}

/// The frontmost application's own signals, one line per window, selection, and menu.
func printFrontmost(_ signals: FrontSignals, target: FrontTarget) {
    print(
        "front bundle=\(target.bundleIdentifier ?? "-") pid=\(target.pid) "
            + "axFocusedApp=\(signals.axFocusedApplication.map(String.init) ?? "-") "
            + "focusedElement=\(signals.focusedElement ?? "-")",
    )
    print("focusedWindow " + (signals.focusedWindow?.fields ?? "none"))
    for (index, window) in signals.windows.enumerated() {
        print("window #\(index) " + window.fields)
    }
    if signals.windows.isEmpty {
        print("windows none")
    }
    printMenus(signals.menus, pid: target.pid)
}

/// The selected bar items and open menus of the application read as `pid`.
func printMenus(_ menus: MenuSignals, pid: pid_t) {
    for selection in menus.selections {
        print(
            "selected pid=\(pid) bar=\(selection.bar) title=\(quoted(selection.title)) "
                + "description=\(quoted(selection.label))",
        )
    }
    for menu in menus.openMenus {
        print(
            "menu pid=\(pid) via=\(menu.via) owner=\(menu.pid.map(String.init) ?? "-") "
                + "frame=\(formatted(menu.frame)) children=\(menu.childCount)",
        )
    }
    if menus.openMenus.isEmpty {
        print("menus pid=\(pid) none")
    }
}

/// Every container in `pid`'s application tree, then how many and what the read cost.
/// A failed read is a finding too — an application that will not answer — so it is
/// printed on stdout with the rest, not only on stderr.
@MainActor
func printContainers(of pid: pid_t, reader: AXUIElementTreeReader) {
    do {
        let tree = try reader.readTree(pid: pid, scope: .application, strategy: .batchedPruned)
        let containers = Container.find(in: tree.elements)
        for container in containers {
            print(container.line(pid: pid))
        }
        print(
            "containers pid=\(pid) count=\(containers.count) elements=\(tree.elements.count) "
                + "read=\(formatted(tree.readDuration.milliseconds))ms",
        )
    } catch let error as AccessibilityReadError {
        print("containers pid=\(pid) failed: \(describe(error))")
    } catch {
        print("containers pid=\(pid) failed: \(error)")
    }
}

@MainActor
func serverWindowLine(_ window: WindowServerWindow) -> String {
    """
    serverWindow layer=\(window.layer) pid=\(window.pid) owner=\(quoted(window.ownerName)) \
    bundle=\(window.bundleIdentifier ?? "-") bounds=\(formatted(window.bounds)) \
    menuBarStrip=\(window.isInMenuBarStrip)
    """
}

/// The processes other than the frontmost one worth an Accessibility read: owners of a
/// window above the normal layer that is not wholly in the menu bar strip, and that are
/// applications — the window server owns the bar itself and answers nothing. In the
/// window server's front-to-back order, each once.
@MainActor
func otherProcesses(in signals: FrontSignals) -> [pid_t] {
    var seen: Set<pid_t> = signals.target.map { [$0.pid] } ?? []
    return signals.serverWindows.compactMap { window -> pid_t? in
        guard !window.isInMenuBarStrip, window.bundleIdentifier != nil,
              seen.insert(window.pid).inserted
        else {
            return nil
        }
        return window.pid
    }
}
