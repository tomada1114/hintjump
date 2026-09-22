import Observation

/// Keeps the four global shortcuts registered to match the configuration, and forwards
/// a press.
///
/// The decision behind ``TriggerRegistering``: what to register (all four entry points,
/// in ``EntryPoint/allCases`` order), that a re-apply starts from nothing, what a
/// refusal leaves behind, and what a press is logged as. `@Observable` so a future
/// Status window can show ``failures`` without a second source of truth.
@MainActor
@Observable
public final class TriggerController {
    /// The bindings the last ``apply(_:)`` could not register — empty when all four did.
    public private(set) var failures: [TriggerRegistrationFailure] = []

    /// Where a press goes, after it is logged. `nil` until the hint session is wired in;
    /// a press is logged either way, so a trigger is observable before it does anything.
    @ObservationIgnored public var onTrigger: (@MainActor (EntryPoint) -> Void)?

    @ObservationIgnored private let registrar: any TriggerRegistering

    /// Registers nothing: registering is ``apply(_:)``'s job, once a configuration is in
    /// force.
    public init(registrar: any TriggerRegistering) {
        self.registrar = registrar
    }

    /// Unregisters every trigger, then registers the four `config` names.
    ///
    /// Always from nothing rather than a diff against what is registered: four Carbon
    /// calls are cheap, and a diff would be one more thing that could disagree with the
    /// OS. The counts and every refusal are logged `.public` — a key combination is a
    /// shortcut, not user data.
    public func apply(_ config: HintjumpConfig) {
        registrar.unregisterAll()
        let bindings = EntryPoint.allCases.map { entryPoint in
            TriggerBinding(entryPoint: entryPoint, combination: config.combination(for: entryPoint))
        }
        failures = registrar.register(bindings) { [weak self] entryPoint in
            self?.handlePress(entryPoint)
        }
        let failed = failures.count
        let registered = bindings.count - failed
        AppLog.triggers.info(
            "triggers registered: \(registered, privacy: .public) ok, \(failed, privacy: .public) failed",
        )
        for failure in failures {
            let entryPoint = failure.binding.entryPoint.rawValue
            let combination = failure.binding.combination.description
            let status = failure.status
            AppLog.triggers.error(
                // swiftlint:disable:next line_length
                "trigger failed to register: \(entryPoint, privacy: .public) \(combination, privacy: .public), status \(status, privacy: .public)",
            )
        }
    }

    /// Logs the press and hands it to ``onTrigger``.
    private func handlePress(_ entryPoint: EntryPoint) {
        AppLog.triggers.info("trigger pressed: \(entryPoint.rawValue, privacy: .public)")
        onTrigger?(entryPoint)
    }
}
