/// One trigger to register: which entry point, on which combination.
public struct TriggerBinding: Equatable, Sendable {
    /// What a press of ``combination`` starts.
    public let entryPoint: EntryPoint
    /// The shortcut, in the configuration file's vocabulary; the adapter translates it.
    public let combination: KeyCombination

    public init(entryPoint: EntryPoint, combination: KeyCombination) {
        self.entryPoint = entryPoint
        self.combination = combination
    }
}

/// A binding the OS refused, with the status it refused it with.
///
/// The status is the raw `OSStatus` as an `Int32` rather than a Core enum: Core only
/// logs it, and the number is what a search for the refusal needs — `-9878`, for
/// instance, is Carbon's "another hotkey already has this combination".
public struct TriggerRegistrationFailure: Equatable, Sendable {
    /// The binding that did not register.
    public let binding: TriggerBinding
    /// The OS's status code for the refusal.
    public let status: Int32

    public init(binding: TriggerBinding, status: Int32) {
        self.binding = binding
        self.status = status
    }
}

/// A port: register global shortcuts, and hear when one is pressed.
///
/// Carbon's `RegisterEventHotKey` answers it, and Carbon is one of the frameworks Core
/// may not import (`docs/architecture.md` › Layers), so the adapter in
/// `HintjumpPlatform` translates a ``KeyCombination`` into a key code and a modifier
/// mask and ``TriggerController`` decides what to register and when. `@MainActor`
/// because the application event target delivers presses on the main thread, and
/// because it keeps a class-backed fake `Sendable` without an `@unchecked` of its own.
@MainActor
public protocol TriggerRegistering: Sendable {
    /// Registers every binding, calling `onPress` with a binding's entry point each
    /// time its combination is pressed.
    ///
    /// A refused binding does not stop the rest: it comes back as a failure and the
    /// others still register, so one combination another app holds costs the user one
    /// trigger rather than all four.
    func register(
        _ bindings: [TriggerBinding],
        onPress: @escaping @MainActor (EntryPoint) -> Void,
    ) -> [TriggerRegistrationFailure]

    /// Unregisters everything ``register(_:onPress:)`` registered. Idempotent: calling
    /// it with nothing registered does nothing.
    func unregisterAll()
}
