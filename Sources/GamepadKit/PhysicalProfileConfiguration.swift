import GameController

/// Everything about a ``PhysicalProfileController`` that differs between apps. The
/// package ships no app's values: each app builds its own and passes it in.
public struct PhysicalProfileConfiguration: Sendable {
    /// Which of the wrapper's pause callbacks the deprecated
    /// `GCController.controllerPausedHandler` also fires for.
    @frozen public enum LegacyPausedHandler: Sendable, Equatable {
        /// Never. The app listens to ``PhysicalProfileController/onPauseRequested``.
        case never
        /// Only for ``PauseTrigger/home``.
        case homeOnly
        /// For every trigger.
        case anyTrigger
    }

    /// Where the wrapper keeps its `playerIndex`.
    @frozen public enum PlayerIndexStorage: Sendable, Equatable {
        /// On the wrapper, forwarded to the real pad on every set.
        case wrapperForwardingToBase
        /// On the real pad only; the wrapper reads it back from there.
        case base
    }

    @frozen public enum LogLevel: Sendable, Equatable {
        /// Once per wrapped pad: its family, pause trigger and bindings.
        case info
        /// Once per button press.
        case debug
    }

    /// The name tables element names resolve through.
    public var mapping: PhysicalProfileMapping
    /// Which pads get a wrapper.
    public var wrapPolicy: WrapPolicy
    /// How the pad opens the app's pause menu.
    public var pausePolicy: PausePolicy
    /// Where each button lands on the synthesized gamepad.
    public var router: InputRouter
    /// Whether the pause trigger's inputs stay released to the game from the moment
    /// it fires until all of them are let go. Never applies to ``PauseTrigger/button(_:)``.
    public var holdsBackPauseInputs: Bool
    /// When the synthesized gamepad reports `buttonOptions`.
    public var optionsExposure: OptionalElementExposure
    /// When the synthesized gamepad reports `buttonHome`.
    public var homeExposure: OptionalElementExposure
    /// Bound buttons whose `preferredSystemGestureState` is disabled on the real pad,
    /// so tvOS does not also treat them as a system Menu press.
    public var systemGestureDisabledInputs: Set<GamepadInput>
    public var legacyPausedHandler: LegacyPausedHandler
    /// Which handler of a synthesized button fires first.
    public var buttonHandlerOrder: SynthesizedButtonInput.HandlerOrder
    public var playerIndexStorage: PlayerIndexStorage
    /// Names a pad the system reports without a vendor name, from its product
    /// category; nil leaves it unnamed. Apps key remaps and mapping files on the
    /// vendor name, and every unnamed pad would otherwise share one entry.
    public var unnamedPadName: (@Sendable (_ productCategory: String) -> String)?
    /// The wrapper's `vendorName`, in place of the pad's own name and of
    /// ``unnamedPadName``; nil (the default) uses those. For an app whose core already
    /// names every pad (iCube's `MFiController::NameFor`), so the two names match.
    public var padName: (@Sendable (GCController) -> String?)?
    /// D-pad-as-stick emulation; nil (the default) leaves the D-pad a D-pad, exactly as
    /// without the feature.
    public var dpadStick: DpadStickSettings?
    /// An extra remote test on top of the product category (iCube's `isMenuRemote`).
    public var isRemote: (@Sendable (GCController) -> Bool)?
    /// Resolves a pad's bindings (element name → input) in place of ``mapping``; nil (the
    /// default) resolves through ``mapping``. For an app whose core binds the same pad
    /// from its own table (iCube's is in C++), so the wrapper and the core cannot
    /// disagree. ``mapping`` still decides the pad's family.
    public var bindingsResolver: (@Sendable (GCController, PadFamily) -> [String: GamepadInput])?
    public var log: (@Sendable (LogLevel, String) -> Void)?

    public init(
        mapping: PhysicalProfileMapping,
        wrapPolicy: WrapPolicy,
        pausePolicy: PausePolicy,
        router: InputRouter = .identity,
        holdsBackPauseInputs: Bool = true,
        optionsExposure: OptionalElementExposure = .whenBound,
        homeExposure: OptionalElementExposure = .whenBound,
        systemGestureDisabledInputs: Set<GamepadInput> = [.menu, .options],
        legacyPausedHandler: LegacyPausedHandler = .never,
        buttonHandlerOrder: SynthesizedButtonInput.HandlerOrder = .valueThenPressed,
        playerIndexStorage: PlayerIndexStorage = .wrapperForwardingToBase,
        unnamedPadName: (@Sendable (_ productCategory: String) -> String)? = {
            PhysicalProfileMapping.fallbackVendorName(productCategory: $0)
        },
        padName: (@Sendable (GCController) -> String?)? = nil,
        dpadStick: DpadStickSettings? = nil,
        isRemote: (@Sendable (GCController) -> Bool)? = nil,
        bindingsResolver: (@Sendable (GCController, PadFamily) -> [String: GamepadInput])? = nil,
        log: (@Sendable (LogLevel, String) -> Void)? = nil
    ) {
        self.mapping = mapping
        self.wrapPolicy = wrapPolicy
        self.pausePolicy = pausePolicy
        self.router = router
        self.holdsBackPauseInputs = holdsBackPauseInputs
        self.optionsExposure = optionsExposure
        self.homeExposure = homeExposure
        self.systemGestureDisabledInputs = systemGestureDisabledInputs
        self.legacyPausedHandler = legacyPausedHandler
        self.buttonHandlerOrder = buttonHandlerOrder
        self.playerIndexStorage = playerIndexStorage
        self.unnamedPadName = unnamedPadName
        self.padName = padName
        self.dpadStick = dpadStick
        self.isRemote = isRemote
        self.bindingsResolver = bindingsResolver
        self.log = log
    }
}
