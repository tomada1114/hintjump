@testable import HintjumpCore
import Testing

extension StatusMenuModelTests {
    /// "Disable in <App>" / "Enable in <App>": what the item reads, and what choosing it
    /// does to the file and to the triggers.
    @MainActor
    @Suite("Disable in <App>")
    struct Disable {
        static let textEdit = DisabledAppsPolicyTests.textEdit
        static let textEditDisabled = HintjumpConfig.defaultFileContents.replacing(
            "disabled = []",
            with: #"disabled = ["com.apple.TextEdit"]"#,
        )

        @Test
        func `no item before any other app was frontmost`() throws {
            let harness = try StatusMenuModelTests.started()

            #expect(harness.model.disableItemTitle == nil)
        }

        @Test
        func `no item for an app with no bundle identifier`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: DisabledAppsPolicyTests.noBundle,
            )

            #expect(harness.model.disableItemTitle == nil)
        }

        @Test
        func `names the frontmost app it is not disabled in`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )

            #expect(harness.model.disableItemTitle == "Disable in TextEdit")
        }

        @Test
        func `offers to enable an app the file already disables`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: Self.textEditDisabled,
                frontmost: Self.textEdit,
            )

            #expect(harness.model.disableItemTitle == "Enable in TextEdit")
            #expect(harness.controller.isSuspended)
        }

        @Test
        func `still names the last other app while Hintjump itself is frontmost`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )

            harness.observer.activate(DisabledAppsPolicyTests.ownProcess)

            #expect(harness.model.disableItemTitle == "Disable in TextEdit")
        }

        @Test
        func `choosing Disable writes the list, keeps the comments, and suspends at once`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.contents == Self.textEditDisabled)
            #expect(harness.store.config.disabledApps == ["com.apple.TextEdit"])
            #expect(harness.controller.isSuspended)
            #expect(harness.registrar.registered.isEmpty)
            #expect(harness.model.disableItemTitle == "Enable in TextEdit")
        }

        @Test
        func `choosing Enable empties the list again and resumes at once`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: Self.textEditDisabled,
                frontmost: Self.textEdit,
            )

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.contents == HintjumpConfig.defaultFileContents)
            #expect(harness.store.config.disabledApps.isEmpty)
            #expect(!harness.controller.isSuspended)
            #expect(harness.registrar.registered == TriggerControllerTests.defaultBindings)
            #expect(harness.model.disableItemTitle == "Disable in TextEdit")
        }

        @Test
        func `choosing Disable after the file was edited to say so writes nothing and suspends`(
        ) throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )
            harness.file.contents = Self.textEditDisabled

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.writes.isEmpty)
            #expect(harness.controller.isSuspended)
            #expect(harness.model.disableItemTitle == "Enable in TextEdit")
        }

        @Test
        func `choosing it with no app to name writes nothing`() throws {
            let harness = try StatusMenuModelTests.started()

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.writes.isEmpty)
            #expect(!harness.controller.isSuspended)
        }

        @Test
        func `a broken file leaves the file, the triggers, and the item unchanged`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )
            let broken = HintjumpConfig.defaultFileContents + "\nhotkey_left = \"x\"\n"
            harness.file.contents = broken

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.contents == broken)
            #expect(harness.file.writes.isEmpty)
            #expect(!harness.controller.isSuspended)
            #expect(harness.registrar.registered == TriggerControllerTests.defaultBindings)
            #expect(harness.model.disableItemTitle == "Disable in TextEdit")
        }

        @Test
        func `an unreadable file leaves the triggers and the item unchanged`() throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )
            harness.file.readError = FakeFileError()

            harness.model.toggleDisabledForLastApp()

            #expect(harness.file.writes.isEmpty)
            #expect(!harness.controller.isSuspended)
            #expect(harness.model.disableItemTitle == "Disable in TextEdit")
        }

        @Test
        func `a reload that adds the frontmost app suspends, and one that removes it resumes`(
        ) throws {
            let harness = try StatusMenuModelTests.started(
                contents: HintjumpConfig.defaultFileContents,
                frontmost: Self.textEdit,
            )
            harness.file.contents = Self.textEditDisabled

            harness.model.reloadConfig()

            #expect(harness.controller.isSuspended)
            #expect(harness.registrar.registered.isEmpty)
            #expect(harness.model.disableItemTitle == "Enable in TextEdit")

            harness.file.contents = HintjumpConfig.defaultFileContents
            harness.model.reloadConfig()

            #expect(!harness.controller.isSuspended)
            #expect(harness.registrar.registered == TriggerControllerTests.defaultBindings)
        }
    }
}
