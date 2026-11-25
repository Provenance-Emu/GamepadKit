import GameController

/// Wraps a GCController the system exposes without an extended gamepad (the Nintendo
/// Switch Online SNES/N64/Mega Drive pads, and plain USB/Bluetooth HID pads) and
/// synthesizes one from its physical input profile, so code that only reads
/// `extendedGamepad` (a core, menu navigation, player assignment) works with it.
///
/// Hand the WRAPPER to whatever reads `extendedGamepad`, and keep it alive in a
/// ``PhysicalProfileControllerRegistry`` for as long as the pad is connected.
///
/// What the wrapper does with the pad's bindings is the app's choice, passed in as a
/// ``PhysicalProfileConfiguration``: the name tables, which pads to wrap, where each
/// button lands, and how pause is detected and delivered.
///
/// Its mutable state is touched only from the GameController handler queue, like the
/// state of the real elements it stands in for.
@objc(GPKPhysicalProfileController)
public final class PhysicalProfileController: GCController, @unchecked Sendable {
    deinit { rampTimer?.cancel() }

    /// The real controller. Its profile elements drive the synthesized gamepad.
    /// `@objc` so Objective-C bridges can reach it by KVC (Provenance's
    /// `PVIsPhysicalProfileController` does).
    @objc public let base: GCController
    public let configuration: PhysicalProfileConfiguration
    /// The synthesized gamepad, also returned from `extendedGamepad`.
    public let synthesized = SynthesizedExtendedGamepad()
    /// Element name → input, as resolved for this pad.
    public private(set) var bindings: [String: GamepadInput] = [:]
    /// Pad family the bindings were resolved for.
    public private(set) var pad: PadFamily = .generic
    /// What opens the pause menu on this pad; nil when the policy found nothing.
    public private(set) var pauseTrigger: PauseTrigger?
    /// Fired (on the GameController handler queue) when ``pauseTrigger`` completes.
    public var onPauseRequested: (@Sendable (PauseTrigger) -> Void)?
    /// Fired when Select is pressed and released on its own while it is part of the
    /// pause chord and the router holds it back from the game.
    public var onSelectTap: (@Sendable () -> Void)?

    private var cUp = false, cDown = false, cLeft = false, cRight = false
    private var storedPlayerIndex: GCControllerPlayerIndex = .indexUnset
    private var pausedHandler: ((GCController) -> Void)?
    var tracker = PauseTriggerTracker(trigger: nil)
    var selectTap = LoneTapTracker(input: .options)
    private var routingContext = RoutingContext(boundInputs: [], pauseTrigger: nil, family: .generic)
    /// Fired when the D-pad mode changes, from the mode chord or from code.
    public var onDpadModeChanged: (@Sendable (DpadMode) -> Void)?
    /// What the D-pad drives. Always ``DpadMode/dpad`` unless the configuration turns
    /// D-pad-as-stick on (``PhysicalProfileConfiguration/dpadStick``).
    public var dpadMode: DpadMode {
        get { storedDpadMode }
        set { setDpadMode(newValue) }
    }

    var storedDpadMode: DpadMode = .dpad
    var dpadEmulator = DpadStickEmulator()
    var rawDpad: (x: Float, y: Float) = (0, 0)
    var rampTimer: DispatchSourceTimer?
    /// Seconds, monotonic. A variable so tests can stand in for the clock.
    var clock: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    /// Profile elements this wrapper installed handlers on, for ``unbind()``.
    private var boundElements: [GCControllerElement] = []
    /// Trigger axes seen below zero, so known to rest at -1 rather than 0.
    private var bipolarAxes: Set<String> = []

    /// True when `controller` has no extended profile and the configuration's
    /// ``WrapPolicy`` accepts its physical profile.
    ///
    /// Apple builds the Switch Online SNES pad from the same description class it uses
    /// for a basic (non-extended) MFi gamepad, so it reports a legacy `gamepad` and a
    /// `microGamepad` but no `extendedGamepad`.
    public static func isNeeded(for controller: GCController, configuration: PhysicalProfileConfiguration) -> Bool {
        guard controller.extendedGamepad == nil, !(controller is PhysicalProfileController) else { return false }
        let pad = configuration.mapping.family(
            vendorName: controller.vendorName,
            productCategory: controller.productCategory
        )
        return configuration.wrapPolicy.shouldWrap(WrapCandidate(
            family: pad,
            productCategory: controller.productCategory,
            hasExtendedGamepad: false,
            hasMicroGamepad: controller.microGamepad != nil,
            isRemote: configuration.isRemote?(controller) ?? false,
            bindings: resolveBindings(for: controller, pad: pad, mapping: configuration.mapping)
        ))
    }

    /// Element name → input for `controller`.
    public static func resolveBindings(
        for controller: GCController,
        pad: PadFamily,
        mapping: PhysicalProfileMapping
    ) -> [String: GamepadInput] {
        let profile = controller.physicalInputProfile
        return mapping.resolveBindings(
            pad: pad,
            elementNames: Array(profile.elements.keys),
            buttonNames: Array(profile.buttons.keys),
            directionNames: Array(profile.dpads.keys),
            axisNames: Array(profile.axes.keys)
        )
    }

    public init(wrapping controller: GCController, configuration: PhysicalProfileConfiguration) {
        base = controller
        self.configuration = configuration
        super.init()
        synthesized.owner = self
        bind()
    }

    private func bind() {
        let profile = base.physicalInputProfile
        pad = configuration.mapping.family(vendorName: base.vendorName, productCategory: base.productCategory)
        bindings = Self.resolveBindings(for: base, pad: pad, mapping: configuration.mapping)
        pauseTrigger = configuration.pausePolicy.trigger(forBindings: bindings, family: pad)
        tracker = PauseTriggerTracker(trigger: pauseTrigger)
        let bound = Set(bindings.values)
        routingContext = RoutingContext(boundInputs: bound, pauseTrigger: pauseTrigger, family: pad)
        synthesized.buttonHandlerOrder = configuration.buttonHandlerOrder
        synthesized.hasOptions = configuration.optionsExposure
            .isExposed(.options, boundInputs: bound, pauseTrigger: pauseTrigger)
        synthesized.hasHome = configuration.homeExposure
            .isExposed(.home, boundInputs: bound, pauseTrigger: pauseTrigger)
        if let dpadStick = configuration.dpadStick {
            storedDpadMode = dpadStick.mode ?? DpadMode.automatic(boundInputs: bound)
            dpadEmulator = DpadStickEmulator(response: dpadStick.response, modifierScale: dpadStick.modifierScale)
        }
        synthesized.hasLeftThumbstickButton = bound.contains(.leftThumbstickButton)
        synthesized.hasRightThumbstickButton = bound.contains(.rightThumbstickButton)
        if let log = configuration.log {
            let described = bindings.sorted { $0.key < $1.key }.map { "\($0.key)→\($0.value.rawValue)" }
                .joined(separator: ", ")
            log(.info, "PhysicalProfileController[\(base.vendorName ?? "?") \(pad.rawValue)] "
                + "pause=\(String(describing: pauseTrigger)): \(described)")
        }

        // `elements` can list one element under several names; each element drives exactly one input.
        var seen: Set<ObjectIdentifier> = []
        for (name, input) in bindings.sorted(by: { $0.key < $1.key }) {
            guard let element = profile.elements[name], seen.insert(ObjectIdentifier(element)).inserted else {
                continue
            }
            bind(element, named: name, to: input)
        }
    }

    private func bind(_ element: GCControllerElement, named name: String, to input: GamepadInput) {
        if input.isDirection {
            guard let source = element as? GCControllerDirectionPad, let target = synthesized.pad(for: input) else {
                return
            }
            let emulatesStick = input == .dpad && configuration.dpadStick != nil
            source.valueChangedHandler = { @Sendable [weak self, weak target] _, x, y in
                guard let self, let target else { return }
                if emulatesStick {
                    self.dpadChanged(x: x, y: y)
                } else if target.update(x: x, y: y) {
                    self.synthesized.notify(target)
                }
            }
            boundElements.append(source)
            return
        }
        if let axis = element as? GCControllerAxisInput {
            if GamepadInput.triggers.contains(input) { bindTriggerAxis(axis, to: input, named: name) }
            return
        }
        guard let source = element as? GCControllerButtonInput else { return }
        if configuration.systemGestureDisabledInputs.contains(input) {
            // Start and Select are game/chord buttons; tvOS would otherwise also
            // treat them as a system Menu (back) press.
            source.preferredSystemGestureState = .disabled
        }
        if input.isCButton {
            source.valueChangedHandler = { @Sendable [weak self] _, _, pressed in
                self?.setCButton(input, pressed: pressed)
            }
        } else {
            source.valueChangedHandler = { @Sendable [weak self] _, value, pressed in
                self?.setButton(input, named: name, value: value, pressed: pressed)
            }
        }
        boundElements.append(source)
    }

    /// Drives a trigger from an axis (``TriggerAxis``).
    private func bindTriggerAxis(_ axis: GCControllerAxisInput, to input: GamepadInput, named name: String) {
        if axis.value < TriggerAxis.initialBipolarThreshold { bipolarAxes.insert(name) }
        axis.valueChangedHandler = { @Sendable [weak self] _, raw in
            guard let self else { return }
            if TriggerAxis.readingIsBipolar(raw) { self.bipolarAxes.insert(name) }
            let state = TriggerAxis.state(forAxisValue: raw, restsAtMinusOne: self.bipolarAxes.contains(name))
            self.setButton(input, named: name, value: state.value, pressed: state.pressed)
        }
        boundElements.append(axis)
    }

    /// Drops the handlers this wrapper installed on the real pad (on disconnect).
    public func unbind() {
        for element in boundElements {
            if let pad = element as? GCControllerDirectionPad {
                pad.valueChangedHandler = nil
            } else if let button = element as? GCControllerButtonInput {
                button.valueChangedHandler = nil
            } else if let axis = element as? GCControllerAxisInput {
                axis.valueChangedHandler = nil
            }
        }
        boundElements.removeAll()
        stopRampTimer()
        onDpadModeChanged = nil
        onPauseRequested = nil
        onSelectTap = nil
        pausedHandler = nil
    }

    /// Forwards a button to the synthesized gamepad, fires the pause callbacks when
    /// the trigger completes, and (when the app asks) holds the trigger's inputs back
    /// from the game until they are released.
    private func setButton(_ input: GamepadInput, named name: String, value: Float, pressed: Bool) {
        let wasHeld = tracker.isHeld(input)
        let outcome = tracker.update(input, pressed: pressed)
        if pressed, !wasHeld, let log = configuration.log {
            log(.debug, "PhysicalProfileController[\(pad.rawValue)]: \(name) → \(input.rawValue)")
        }
        if pauseTrigger?.inputs.contains(.options) == true,
           selectTap.update(input, pressed: pressed, wasHeld: wasHeld, held: tracker.held),
           configuration.router.route(.options, routingContext) == nil {
            onSelectTap?()
        }

        if let dpadStick = configuration.dpadStick {
            if input == dpadStick.modifier { refreshEmulatedStick() }
            // Letting go of the mode chord hands the D-pad back to the game.
            if input == dpadStick.modeChord, !pressed { applyDpad() }
        }

        guard let trigger = pauseTrigger, outcome != .forward else {
            apply(input, value: value, pressed: pressed)
            return
        }
        let holdsBack = configuration.holdsBackPauseInputs && trigger.canHoldBackInputs
        switch outcome {
        case .fired:
            selectTap.cancel()
            if holdsBack {
                for released in trigger.inputs {
                    apply(released, value: 0, pressed: false)
                }
            } else {
                apply(input, value: value, pressed: pressed)
            }
            firePause(trigger)
        case .latched:
            if !holdsBack { apply(input, value: value, pressed: pressed) }
        case .forward:
            break
        }
    }

    private func firePause(_ trigger: PauseTrigger) {
        onPauseRequested?(trigger)
        switch configuration.legacyPausedHandler {
        case .never: break
        case .homeOnly: if trigger == .home { pausedHandler?(self) }
        case .anyTrigger: pausedHandler?(self)
        }
    }

    private func apply(_ input: GamepadInput, value: Float, pressed: Bool) {
        guard let route = configuration.router.route(input, routingContext),
              let element = synthesized.button(for: route.target) else { return }
        // A trigger fed from another (digital) button is a full press.
        let isDigitalTrigger = GamepadInput.triggers.contains(route.target) && route.target != input
        let routedValue = isDigitalTrigger ? (pressed ? 1 : 0) : value
        if element.update(value: routedValue, pressed: pressed) {
            synthesized.notify(element)
        }
        if let mirror = route.pressedOnlyMirror, mirror != route.target {
            synthesized.button(for: mirror)?.update(value: value, pressed: pressed, notifyValueHandler: false)
        }
    }

    /// The N64 C cluster is four digital buttons; present them as the right stick.
    private func setCButton(_ input: GamepadInput, pressed: Bool) {
        switch input {
        case .rightStickUp: cUp = pressed
        case .rightStickDown: cDown = pressed
        case .rightStickLeft: cLeft = pressed
        case .rightStickRight: cRight = pressed
        default: return
        }
        let x: Float = (cRight ? 1 : 0) - (cLeft ? 1 : 0)
        let y: Float = (cUp ? 1 : 0) - (cDown ? 1 : 0)
        if synthesized.synthesizedRightThumbstick.update(x: x, y: y) {
            synthesized.notify(synthesized.synthesizedRightThumbstick)
        }
    }

    // MARK: GCController

    override public var extendedGamepad: GCExtendedGamepad? { synthesized }
    override public var microGamepad: GCMicroGamepad? { nil }
    override public var physicalInputProfile: GCPhysicalInputProfile { base.physicalInputProfile }
    /// Never nil when the configuration names unnamed pads
    /// (``PhysicalProfileConfiguration/unnamedPadName``).
    override public var vendorName: String? {
        base.vendorName ?? configuration.unnamedPadName?(base.productCategory)
    }

    override public var productCategory: String { base.productCategory }
    override public var isAttachedToDevice: Bool { false }
    override public var haptics: GCDeviceHaptics? { base.haptics }
    override public var light: GCDeviceLight? { base.light }
    override public var battery: GCDeviceBattery? { base.battery }
    override public var motion: GCMotion? { base.motion }

    /// Polling readers capture a copy; the synthesized elements are plain values, so
    /// the controller serves as its own snapshot.
    override public func capture() -> GCController { self }

    override public var playerIndex: GCControllerPlayerIndex {
        get {
            switch configuration.playerIndexStorage {
            case .wrapperForwardingToBase: return storedPlayerIndex
            case .base: return base.playerIndex
            }
        }
        set {
            storedPlayerIndex = newValue
            base.playerIndex = newValue
        }
    }

    /// Fired by the pad's ``pauseTrigger`` as the configuration's
    /// ``PhysicalProfileConfiguration/legacyPausedHandler`` says; never by Start alone.
    @available(iOS, deprecated: 13.0, message: "Use onPauseRequested.")
    @available(tvOS, deprecated: 13.0, message: "Use onPauseRequested.")
    @available(macOS, deprecated: 10.15, message: "Use onPauseRequested.")
    override public var controllerPausedHandler: ((GCController) -> Void)? {
        get { pausedHandler }
        set { pausedHandler = newValue }
    }
}
