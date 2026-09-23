@testable import HintjumpCore
import Testing

/// One key changed through ``ConfigStore/update(_:)``: the edit, and the one span of
/// ``ConfigStoreTests/Update/messyFile`` it should replace.
struct KeyEdit: CustomTestStringConvertible {
    static let all: [Self] = [
        Self(
            key: ConfigSchema.clickInWindow,
            before: #"click_in_window="ctrl+shift+space""#,
            after: #"click_in_window="ctrl+shift+k""#,
        ) { $0.clickInWindow = try KeyCombination.parse("ctrl+shift+k") },
        Self(
            key: ConfigSchema.rightClickInWindow,
            before: #"right_click_in_window = "ctrl+alt+shift+space""#,
            after: #"right_click_in_window = "ctrl+alt+k""#,
        ) { $0.rightClickInWindow = try KeyCombination.parse("ctrl+alt+k") },
        Self(
            key: ConfigSchema.appMenus,
            before: #"app_menus =   "ctrl+shift+m""#,
            after: #"app_menus =   "shift+cmd+m""#,
        ) { $0.appMenus = try KeyCombination.parse("cmd+shift+m") },
        Self(
            key: ConfigSchema.statusIcons,
            before: #"status_icons = "shift+ctrl+s""#,
            after: #"status_icons = "ctrl+shift+i""#,
        ) { $0.statusIcons = try KeyCombination.parse("ctrl+shift+i") },
        Self(
            key: ConfigSchema.characters,
            before: #"characters = "asdfghjklqwertyuiop""#,
            after: #"characters = "qwertyuiop""#,
        ) { $0.hintCharacters = Array("qwertyuiop") },
        Self(
            key: ConfigSchema.disabled,
            before: #"disabled    =  [ "com.apple.Terminal" ]"#,
            after: #"disabled    =  ["com.apple.Terminal", "com.apple.Safari"]"#,
        ) { $0.disabledApps.append("com.apple.Safari") },
        Self(
            key: ConfigSchema.launchAtLogin,
            before: "launch_at_login   =    false",
            after: "launch_at_login   =    true",
        ) { $0.launchAtLogin = true },
    ]

    let key: String
    /// The text the file holds for this key before the edit.
    let before: String
    /// The same text after it — only the value differs.
    let after: String
    /// Applies the edit to a configuration; throws only for a combination that fails to
    /// parse, which would be a mistake in the test itself.
    let edit: @Sendable (inout HintjumpConfig) throws -> Void

    var testDescription: String {
        key
    }
}

extension ConfigStoreTests {
    /// Writing any key back: only its value changes, a broken or rejected result is
    /// never written, and what was written is what the store adopts.
    @MainActor
    @Suite("update")
    struct Update {
        /// Every key, with comments, odd spacing, a key order the app did not write, and
        /// a trigger spelled in a non-canonical modifier order.
        static let messyFile = """
        # my own notes, do not lose these

        [startup]
        launch_at_login   =    false   # I like it this way

        [triggers]
        # my shortcuts
        click_in_window="ctrl+shift+space"  # tight
        right_click_in_window = "ctrl+alt+shift+space"
        app_menus =   "ctrl+shift+m"
        status_icons = "shift+ctrl+s" # written my way

        [apps]
        # the ones I keep off
        disabled    =  [ "com.apple.Terminal" ]   # trailing note

        [hints]
        characters = "asdfghjklqwertyuiop"
        # a dangling comment at the end

        """

        @Test(arguments: KeyEdit.all)
        func `each key round-trips with every other byte identical`(_ edit: KeyEdit) throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)
            var expected = try ConfigSchema.config(from: Self.messyFile)
            try edit.edit(&expected)

            let adopted = try store.update { $0 = expected }

            let written = Self.messyFile.replacingOccurrences(of: edit.before, with: edit.after)
            #expect(file.writes == [written])
            #expect(adopted == expected)
            #expect(store.config == expected)
            #expect(store.lastLoad == ConfigStore.LoadRecord(
                date: fakeClock,
                result: .success(expected),
            ))
        }

        @Test
        func `several keys change in one write`() throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)

            try store.update { config in
                config.hintCharacters = Array("qwertyuiop")
                config.launchAtLogin = true
            }

            let written = Self.messyFile
                .replacingOccurrences(of: "=    false", with: "=    true")
                .replacingOccurrences(of: "\"asdfghjklqwertyuiop\"", with: "\"qwertyuiop\"")
            #expect(file.writes == [written])
        }

        @Test
        func `appends a key its section is missing, and a section the file is missing`() throws {
            let file =
                FakeConfigFile(contents: "# mine\n[triggers]\napp_menus = \"ctrl+shift+m\"\n")
            let store = ConfigStoreTests.store(file)

            try store.update { config in
                config.statusIcons = KeyCombination(modifiers: [.control, .option], key: .space)
                config.launchAtLogin = true
            }

            #expect(file.contents == """
            # mine
            [triggers]
            app_menus = "ctrl+shift+m"
            status_icons = "ctrl+alt+space"

            [startup]
            launch_at_login = true

            """)
            #expect(store.config.statusIcons.description == "ctrl+alt+space")
            #expect(store.config.launchAtLogin)
        }

        @Test
        func `an unchanged configuration writes nothing and adopts the file`() throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)

            let adopted = try store.update { _ in
                // Nothing changes.
            }

            #expect(file.writes.isEmpty)
            #expect(try adopted == (ConfigSchema.config(from: Self.messyFile)))
            #expect(store.config == adopted)
        }

        @Test
        func `a change back to the value the file already has writes nothing`() throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)

            try store.update { config in
                // The file spells it `shift+ctrl+s`; the same combination is no change.
                config.statusIcons = KeyCombination(modifiers: [.shift, .control], key: .letterS)
            }

            #expect(file.writes.isEmpty)
        }

        @Test
        func `a missing file starts from the default's text`() throws {
            let file = FakeConfigFile(contents: nil)
            let store = ConfigStoreTests.store(file)

            try store.update { $0.launchAtLogin = true }

            let written = HintjumpConfig.defaultFileContents.replacingOccurrences(
                of: "launch_at_login = false",
                with: "launch_at_login = true",
            )
            #expect(file.writes == [written])
        }

        @Test
        func `a broken file refuses the update and is left untouched`() {
            let broken = Self.messyFile + "hotkey_left = \"x\"\n"
            let file = FakeConfigFile(contents: broken)
            let store = ConfigStoreTests.store(file)

            #expect(throws: ConfigError(line: 20, reason: "unknown key `hotkey_left`")) {
                try store.update { $0.launchAtLogin = true }
            }
            #expect(file.writes.isEmpty)
            #expect(file.contents == broken)
            #expect(store.config == .default)
            #expect(store.lastLoad == nil)
        }

        @Test
        func `a change that makes two triggers equal is rejected without a write`() throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)
            try store.load()
            let before = store.config

            #expect(throws: ConfigError(
                line: 10,
                reason: "`app_menus` uses the same combination as `click_in_window` — every trigger needs its own",
            )) {
                try store.update { $0.appMenus = $0.clickInWindow }
            }
            #expect(file.writes.isEmpty)
            #expect(store.config == before)
        }

        @Test
        func `too few hint characters are rejected with the line a hand edit would get`() {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)

            #expect(throws: ConfigError(
                line: 18,
                reason: "hints need at least 8 characters, and this has 3",
            )) {
                try store.update { $0.hintCharacters = Array("abc") }
            }
            #expect(file.writes.isEmpty)
        }

        @Test
        func `a value the file cannot hold is rejected without a write`() {
            let file = FakeConfigFile(contents: Self.messyFile)
            let store = ConfigStoreTests.store(file)

            #expect(throws: ConfigError(line: 15, reason: "unterminated string")) {
                try store.update { $0.disabledApps = ["line\nbreak"] }
            }
            #expect(file.writes.isEmpty)
        }

        @Test
        func `an unreadable file refuses the update`() {
            let file = FakeConfigFile(contents: Self.messyFile)
            file.readError = FakeFileError()
            let store = ConfigStoreTests.store(file)

            #expect(throws: FakeFileError()) {
                try store.update { $0.launchAtLogin = true }
            }
            #expect(file.writes.isEmpty)
        }

        @Test
        func `a failed write adopts nothing`() {
            let file = FakeConfigFile(contents: Self.messyFile)
            file.writeError = FakeFileError()
            let store = ConfigStoreTests.store(file)

            #expect(throws: FakeFileError()) {
                try store.update { $0.launchAtLogin = true }
            }
            #expect(store.config == .default)
            #expect(store.lastLoad == nil)
        }

        @Test
        func `an adopted launch_at_login is applied to the login item`() throws {
            let file = FakeConfigFile(contents: Self.messyFile)
            let loginItem = FakeLoginItem(isRegistered: false)
            let store = ConfigStoreTests.store(file, loginItem: loginItem)

            try store.update { $0.launchAtLogin = true }
            try store.update { $0.launchAtLogin = false }

            #expect(loginItem.setCalls == [true, false])
        }
    }
}
