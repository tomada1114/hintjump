import Carbon.HIToolbox
import HintjumpCore

/// `@convention(c)`, so it captures nothing: the registrar arrives through `refcon`, and
/// only the hotkey's identifier — a plain value — is handed on.
///
/// The application event target dispatches on the main thread, which is this callback's
/// licence for `MainActor.assumeIsolated` (`.agents/skills/integrating-system-apis/
/// references/c-callbacks.md` › "Carbon hotkey: no run-loop source at all").
private let triggerHotKeyHandler: EventHandlerUPP = { _, event, refcon in
    guard let event, let refcon else {
        return OSStatus(eventNotHandledErr)
    }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier,
    )
    guard status == noErr else {
        return status
    }
    let registrar = Unmanaged<CarbonTriggerRegistrar>.fromOpaque(refcon).takeUnretainedValue()
    let pressed = identifier
    MainActor.assumeIsolated { registrar.fire(pressed) }
    return noErr
}

/// The Carbon `RegisterEventHotKey` adapter for ``HintjumpCore/TriggerRegistering``.
///
/// Carbon is deprecated and still the only system-wide hotkey API that needs no TCC
/// grant (`docs/architecture.md` › Global hotkeys). Translation only: a
/// ``HintjumpCore/KeyCombination`` becomes a virtual key code and a Carbon modifier mask
/// (`CarbonTriggerRegistrar+Translation.swift`), a refusal becomes a
/// ``HintjumpCore/TriggerRegistrationFailure``, and a press becomes its
/// ``HintjumpCore/EntryPoint``. What to register and when is
/// ``HintjumpCore/TriggerController``'s decision.
///
/// The event handler's refcon is a manual retain of `self`, so `deinit` never runs while
/// anything is registered: ``unregisterAll()`` is the teardown, and it is idempotent.
@MainActor
public final class CarbonTriggerRegistrar: TriggerRegistering {
    /// The four-character code (`HJMP`) every hotkey this app registers carries, so a
    /// press is recognised as one of ours.
    private static let signature: OSType = 0x484A_4D50

    private var eventHandler: EventHandlerRef?
    private var callbackContext: UnsafeMutableRawPointer?
    private var hotKeys: [EventHotKeyRef] = []
    private var reportPress: (@MainActor (EntryPoint) -> Void)?

    public init() {
        // Nothing is installed until register(_:onPress:): a hotkey is a resource, not
        // a constructor.
    }

    /// Installs the press handler if it is not installed yet, then registers each
    /// binding; a binding Carbon refuses comes back with the refusal's status and the
    /// rest still register.
    public func register(
        _ bindings: [TriggerBinding],
        onPress: @escaping @MainActor (EntryPoint) -> Void,
    ) -> [TriggerRegistrationFailure] {
        let installStatus = installHandlerIfNeeded()
        guard installStatus == noErr else {
            return bindings.map { TriggerRegistrationFailure(binding: $0, status: installStatus) }
        }
        reportPress = onPress
        return bindings.compactMap(registerHotKey)
    }

    /// Unregisters every hotkey, removes the handler, then releases the refcon — the
    /// reverse of setup, so no press can arrive through a released context.
    public func unregisterAll() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys = []
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        reportPress = nil
        if let callbackContext {
            Unmanaged<CarbonTriggerRegistrar>.fromOpaque(callbackContext).release()
            self.callbackContext = nil
        }
    }

    /// Hands a press to the `onPress` of the last registration, as its entry point.
    func fire(_ identifier: EventHotKeyID) {
        let index = Int(identifier.id)
        guard identifier.signature == Self.signature,
              EntryPoint.allCases.indices.contains(index)
        else {
            return
        }
        reportPress?(EntryPoint.allCases[index])
    }

    /// Installs the one `kEventHotKeyPressed` handler on the application target, with a
    /// retained `self` as its refcon — released here if the install fails, and in
    /// ``unregisterAll()`` otherwise.
    private func installHandlerIfNeeded() -> OSStatus {
        guard eventHandler == nil else {
            return noErr
        }
        let context = Unmanaged.passRetained(self).toOpaque()
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed),
        )
        var installed: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            triggerHotKeyHandler,
            1,
            &spec,
            context,
            &installed,
        )
        guard status == noErr, let installed else {
            Unmanaged<CarbonTriggerRegistrar>.fromOpaque(context).release()
            return status == noErr ? OSStatus(eventInternalErr) : status
        }
        eventHandler = installed
        callbackContext = context
        return noErr
    }

    /// Registers one binding, answering its failure or `nil` when it registered.
    ///
    /// The hotkey's id is the entry point's index in ``HintjumpCore/EntryPoint/allCases``,
    /// which is how ``fire(_:)`` maps a press back.
    private func registerHotKey(_ binding: TriggerBinding) -> TriggerRegistrationFailure? {
        guard let index = EntryPoint.allCases.firstIndex(of: binding.entryPoint),
              let keyCode = Self.keyCode(for: binding.combination.key)
        else {
            return TriggerRegistrationFailure(binding: binding, status: OSStatus(paramErr))
        }
        var registered: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            Self.modifierMask(for: binding.combination.modifiers),
            EventHotKeyID(signature: Self.signature, id: UInt32(index)),
            GetApplicationEventTarget(),
            0,
            &registered,
        )
        guard status == noErr, let registered else {
            let refusal = status == noErr ? OSStatus(eventInternalErr) : status
            return TriggerRegistrationFailure(binding: binding, status: refusal)
        }
        hotKeys.append(registered)
        return nil
    }
}
