# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- Configuration file at `~/.config/hintjump/config.toml`, written with its comments the
  first time Hintjump runs and re-read on request (no file watching). It accepts a
  documented TOML subset — `#` comments, `[section]` headers, strings, string arrays,
  and booleans — and every mistake in it is reported as `Line N: <reason>`. Defaults:
  the triggers `ctrl+shift+space` (click in window), `ctrl+alt+shift+space` (right-click
  in window), `ctrl+shift+m` (app menus), and `ctrl+shift+s` (status icons); the hint
  characters `asdfghjklqwertyuiopzxcvbnm`; no disabled apps; and launch at login off.
  Disabling Hintjump in an app rewrites only the `disabled` list, leaving the rest of
  the file — comments included — untouched
- Accessibility tree reading: the `AccessibilityTreeReading` port, its `AXUIElementTreeReader`
  adapter, and the `hintjump-probe` command-line tool (`just probe`) the first verifications use
- The app runs as a menu-bar agent: no Dock tile or app-switcher entry, a status item
  whose menu holds a single "Quit Hintjump" item until the status menu lands
- The app asks for Accessibility access at launch: the `AccessibilityTrustChecking` port and
  its `SystemAccessibilityTrust` adapter, a `SystemSettingsOpening` port for the Status
  window's future "Open System Settings…" button, and an `AccessibilityGateViewModel` that
  refreshes on launch and on becoming active and prompts at most once per process
- The app is not sandboxed: it needs Accessibility access to read and click other apps' controls
- The `launch_at_login` config key works: at launch and on the status menu's new
  "Reload Config" item, Hintjump registers or unregisters itself as a login item
  (System Settings › General › Login Items) to match it, through the
  `LoginItemRegistering` port and its `SMAppServiceLoginItem` adapter. A login item the
  system refuses to change is logged and does not fail the reload; one switched off in
  System Settings is left off
- Click synthesis: the `ClickPerforming` port and its `CGEventClickPerformer` adapter post a
  left or right click at a screen point as a synthesized mouse press and release, leaving
  the pointer where it clicked; without the Accessibility grant they refuse rather than
  post a click the system would drop. Nothing calls it yet; typing a hint will
- The four triggers in the config file are registered as global shortcuts (Carbon
  `RegisterEventHotKey`, no permission needed) at launch and again on every successful
  "Reload Config", through the `TriggerRegistering` port and its `CarbonTriggerRegistrar`
  adapter. A press is logged as `trigger pressed: <trigger>` until the hint session
  lands; a combination another app already holds is logged with its status, and the
  other triggers still register. A reload that fails leaves the registered triggers as
  they were
- The status menu gains "Open Config File", which opens `~/.config/hintjump/config.toml`
  in the default plain-text editor, next to "Reload Config"
- Clicking and right-clicking in the frontmost window with hints: ⌃⇧Space shows labels
  on the frontmost window's clickable elements and typing one left-clicks it; ⌃⌥⇧Space
  does the same with a right click, with outlined labels and a "Right click" chip. Esc,
  the same shortcut again, or a mouse click elsewhere closes the labels. The overlay
  takes the typed label without activating Hintjump, so the app being clicked keeps its
  focus and its menu bar, and without the Input Monitoring permission. Labels are typed
  with an ABC (US-layout) input source
- Per-app disable from the status menu: `Disable in <App>` names the last app that was
  frontmost other than Hintjump and adds its bundle identifier to `[apps] disabled`
  (rewriting only that list, comments intact); `Enable in <App>` takes it out again.
  While a disabled app is frontmost all four triggers are unregistered, so their key
  combinations reach that app, and they come back as soon as another app is in front.
  A reload that adds or removes the frontmost app takes effect at once
- Hints on the menu bar's app menus: ⌃⇧M labels the frontmost app's menu bar titles,
  from the Apple menu to Help, left to right, and typing a label opens that menu with a
  left click; macOS's own menu keys take over from there. The accessibility reader
  gains a depth limit, so reading the bar costs its titles and not every item of every
  closed menu under them
- Hints on the menu bar's status items: ⌃⇧S labels every visible status item — other
  apps', Control Center's (Wi-Fi, the clock, and the rest), and Hintjump's own — left
  to right, and typing a label left-clicks it. The items come from the on-screen window
  list in one call, with no new permission; one hidden behind the camera housing gets
  no label. It works even while Hintjump's own window is frontmost
- Hints on an open context menu, panel, sheet, or popover: ⌃⇧Space and ⌃⌥⇧Space now
  label whatever is on top of the frontmost window — a panel another app opened with
  the keyboard focus (Control Center's Wi-Fi and other panels, Notification Center,
  Spotlight, a launcher), an open context menu, a sheet or save-changes alert, or a
  popover — and the window itself otherwise. An open menu bar menu and a floating
  panel such as Fonts fall back to the window. The `shown` log line names the container
  that was labeled (`container=contextMenu scope=popUpMenu pid=…`)
- The status item shows a hint-tag icon instead of the placeholder symbol: a monochrome
  template image that follows the menu bar's light or dark appearance, the outline of a
  rounded tag with a pointer arrow inside. Its update-dot and config-error variants are
  drawn too — the error as a filled pill with a "!" cut out of it, large enough to read
  at the menu bar's real size — but nothing shows those variants yet
- In the frontmost window, single-character labels go first to tabs, sidebar rows (also
  behind an icon rail, as in Slack and VS Code), and the links in a web page's main
  content. Toolbar buttons, a site's header and navigation bar, and links inside an
  embedded frame get two-character labels (`docs/research/target-counts.md`)

### Changed

- A window's close, minimize, zoom, and full-screen buttons now get the last labels in
  every window, dialogs included, instead of taking single-character labels
- One spot on screen now gets one label: a list row no longer carries separate labels
  for its cells and its name (Finder's list view), a control and an invisible twin of
  the same size share one, and an Electron window's window-sized click-through groups
  get none — so fewer targets need two-character labels
- A button or link now takes one label for its whole area: the icon and title inside it
  that Electron apps report as pressable no longer get labels of their own, so each
  Claude Desktop sidebar entry takes one label instead of three
- In a web app shell such as Claude Desktop, the sidebar's entries — its sessions,
  New chat, and the settings button — now take single-character labels ahead of the
  window's top bar, whose buttons get two-character ones; a web page's own sidebar in
  a browser is unaffected

### Fixed

- An empty embedded frame, such as an ad scrolled out of view, no longer wakes a
  browser's accessibility tree and makes it read twice; only an empty top-level web
  area does
- A hint-character set of 8–16 characters, or a window with more than 276 targets, no
  longer leaves targets without a label: single-character labels give way to
  two-character ones only when labels would otherwise run out
- A popover opened from inside another popover, or from a control in a sheet, is now
  what the click-in-window triggers label, rather than the outer popover or the whole
  sheet behind it
- A sidebar item whose row is disabled, too small, or outside the window, and so takes
  no label itself, now ranks the pressable element inside it with the sidebar's rows
  rather than leaving the item with no likely target
- A list-view row hidden behind its column header, such as the first row Finder's list
  view reports under its "Name" header, no longer takes a label whose click re-sorts
  the list
- A split view's divider, such as Claude Desktop's "Resize sidebar" splitter, no longer
  takes a label on the invisible boundary between two panes: a splitter is only ever
  dragged

[Unreleased]: https://github.com/tomada1114/hintjump/commits/main
