/// One key of the file: where it lives, and its value as the file would hold it.
struct ConfigSetting: Equatable {
    let section: String
    let key: String
    let value: TOMLValue
}

/// The way back from a ``HintjumpConfig`` to the file: the inverse of reading it, key
/// by key, for ``ConfigRewriter`` to write.
extension ConfigSchema {
    /// Every key `config` holds, in schema order: the sections and keys in the order the
    /// default file lists them.
    ///
    /// A trigger is written in its canonical `ctrl+alt+shift+cmd` spelling, so two
    /// configurations that hold the same combination render the same value however the
    /// file spelled it.
    static func settings(of config: HintjumpConfig) -> [ConfigSetting] {
        let triggers = config.triggers.map { trigger in
            ConfigSetting(
                section: triggersSection,
                key: trigger.key,
                value: .string(trigger.combination.description),
            )
        }
        return triggers + [
            ConfigSetting(
                section: hintsSection,
                key: characters,
                value: .string(String(config.hintCharacters)),
            ),
            ConfigSetting(
                section: appsSection,
                key: disabled,
                value: .stringArray(config.disabledApps),
            ),
            ConfigSetting(
                section: startupSection,
                key: launchAtLogin,
                value: .boolean(config.launchAtLogin),
            ),
        ]
    }
}
