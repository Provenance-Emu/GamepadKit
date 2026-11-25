import GameController

/// Extended gamepad backed by settable elements; ``PhysicalProfileController``
/// drives it from a pad's physical input profile.
public final class SynthesizedExtendedGamepad: GCExtendedGamepad, @unchecked Sendable {
    public let synthesizedDpad = SynthesizedDirectionPad()
    public let synthesizedLeftThumbstick = SynthesizedDirectionPad()
    public let synthesizedRightThumbstick = SynthesizedDirectionPad()
    private let synthesizedButtonA = SynthesizedButtonInput()
    private let synthesizedButtonB = SynthesizedButtonInput()
    private let synthesizedButtonX = SynthesizedButtonInput()
    private let synthesizedButtonY = SynthesizedButtonInput()
    private let synthesizedLeftShoulder = SynthesizedButtonInput()
    private let synthesizedRightShoulder = SynthesizedButtonInput()
    private let synthesizedLeftTrigger = SynthesizedButtonInput()
    private let synthesizedRightTrigger = SynthesizedButtonInput()
    private let synthesizedMenu = SynthesizedButtonInput()
    private let synthesizedOptions = SynthesizedButtonInput()
    private let synthesizedHome = SynthesizedButtonInput()
    private let synthesizedLeftThumbstickButton = SynthesizedButtonInput()
    private let synthesizedRightThumbstickButton = SynthesizedButtonInput()

    /// The optional buttons are nil unless these are set, so pause routing, default
    /// bindings and remap UI see what the physical pad has (or what the app's
    /// ``OptionalElementExposure`` says they should see).
    public var hasOptions = false
    public var hasHome = false
    public var hasLeftThumbstickButton = false
    public var hasRightThumbstickButton = false

    /// Handler order of every button, including the direction buttons of the pads.
    public var buttonHandlerOrder: SynthesizedButtonInput.HandlerOrder = .valueThenPressed {
        didSet {
            for input in GamepadInput.allCases {
                button(for: input)?.handlerOrder = buttonHandlerOrder
                pad(for: input)?.buttonHandlerOrder = buttonHandlerOrder
            }
        }
    }

    public weak var owner: GCController?
    private var storedValueChangedHandler: GCExtendedGamepadValueChangedHandler?

    override public var controller: GCController? { owner }

    override public var dpad: GCControllerDirectionPad { synthesizedDpad }
    override public var leftThumbstick: GCControllerDirectionPad { synthesizedLeftThumbstick }
    override public var rightThumbstick: GCControllerDirectionPad { synthesizedRightThumbstick }
    override public var buttonA: GCControllerButtonInput { synthesizedButtonA }
    override public var buttonB: GCControllerButtonInput { synthesizedButtonB }
    override public var buttonX: GCControllerButtonInput { synthesizedButtonX }
    override public var buttonY: GCControllerButtonInput { synthesizedButtonY }
    override public var leftShoulder: GCControllerButtonInput { synthesizedLeftShoulder }
    override public var rightShoulder: GCControllerButtonInput { synthesizedRightShoulder }
    override public var leftTrigger: GCControllerButtonInput { synthesizedLeftTrigger }
    override public var rightTrigger: GCControllerButtonInput { synthesizedRightTrigger }
    override public var buttonMenu: GCControllerButtonInput { synthesizedMenu }
    override public var buttonOptions: GCControllerButtonInput? { hasOptions ? synthesizedOptions : nil }
    override public var buttonHome: GCControllerButtonInput? { hasHome ? synthesizedHome : nil }
    override public var leftThumbstickButton: GCControllerButtonInput? {
        hasLeftThumbstickButton ? synthesizedLeftThumbstickButton : nil
    }

    override public var rightThumbstickButton: GCControllerButtonInput? {
        hasRightThumbstickButton ? synthesizedRightThumbstickButton : nil
    }

    override public var valueChangedHandler: GCExtendedGamepadValueChangedHandler? {
        get { storedValueChangedHandler }
        set { storedValueChangedHandler = newValue }
    }

    /// Element for a synthesized button input, or nil for pads and stick directions.
    /// Returns the element whether or not it is currently exposed.
    public func button(for input: GamepadInput) -> SynthesizedButtonInput? {
        switch input {
        case .buttonA: return synthesizedButtonA
        case .buttonB: return synthesizedButtonB
        case .buttonX: return synthesizedButtonX
        case .buttonY: return synthesizedButtonY
        case .leftShoulder: return synthesizedLeftShoulder
        case .rightShoulder: return synthesizedRightShoulder
        case .leftTrigger: return synthesizedLeftTrigger
        case .rightTrigger: return synthesizedRightTrigger
        case .menu: return synthesizedMenu
        case .options: return synthesizedOptions
        case .home: return synthesizedHome
        case .leftThumbstickButton: return synthesizedLeftThumbstickButton
        case .rightThumbstickButton: return synthesizedRightThumbstickButton
        default: return nil
        }
    }

    public func pad(for input: GamepadInput) -> SynthesizedDirectionPad? {
        switch input {
        case .dpad: return synthesizedDpad
        case .leftThumbstick: return synthesizedLeftThumbstick
        case .rightThumbstick: return synthesizedRightThumbstick
        default: return nil
        }
    }

    /// Tells whole-gamepad observers (menu navigation, resume-from-pause) that `element` changed.
    public func notify(_ element: GCControllerElement) {
        storedValueChangedHandler?(self, element)
    }
}
