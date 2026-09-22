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

[Unreleased]: https://github.com/tomada1114/hintjump/commits/main
