import GameController

/// A button whose state is set from code. Backs the elements of a
/// ``SynthesizedExtendedGamepad``.
///
/// `valueChangedHandler` and `pressedChangedHandler` are kept in SEPARATE slots, as
/// on a real element: a core typically hooks `valueChangedHandler`, while an app's
/// menus and pause bindings use `pressedChangedHandler` and nil it on teardown. With
/// one shared slot a menu teardown would unbind gameplay input.
public final class SynthesizedButtonInput: GCControllerButtonInput, @unchecked Sendable {
    /// Which of the two handlers hears about a change first.
    public enum HandlerOrder: Sendable, Equatable {
        /// `valueChangedHandler`, then `pressedChangedHandler`. iFly.
        case valueThenPressed
        /// `pressedChangedHandler`, then `valueChangedHandler`. iCube.
        case pressedThenValue
    }

    public var handlerOrder: HandlerOrder = .valueThenPressed
    private var storedValue: Float = 0
    private var storedPressed = false
    private var storedValueChangedHandler: GCControllerButtonValueChangedHandler?
    private var storedPressedChangedHandler: GCControllerButtonValueChangedHandler?

    override public var value: Float { storedValue }
    override public var isPressed: Bool { storedPressed }

    override public var valueChangedHandler: GCControllerButtonValueChangedHandler? {
        get { storedValueChangedHandler }
        set { storedValueChangedHandler = newValue }
    }

    override public var pressedChangedHandler: GCControllerButtonValueChangedHandler? {
        get { storedPressedChangedHandler }
        set { storedPressedChangedHandler = newValue }
    }

    /// Sets the state and fires the handlers, in ``handlerOrder``: `valueChangedHandler`
    /// on any change, `pressedChangedHandler` when the pressed state flips.
    /// - Parameter notifyValueHandler: false to fire only `pressedChangedHandler`, so
    ///   an app's menus see the press and a core that hooks the value handler doesn't.
    /// - Returns: whether anything changed.
    @discardableResult
    public func update(value: Float, pressed: Bool, notifyValueHandler: Bool = true) -> Bool {
        let pressedChanged = pressed != storedPressed
        let valueChanged = value != storedValue
        guard pressedChanged || valueChanged else { return false }
        storedValue = value
        storedPressed = pressed
        if handlerOrder == .pressedThenValue, pressedChanged {
            storedPressedChangedHandler?(self, value, pressed)
        }
        if notifyValueHandler {
            storedValueChangedHandler?(self, value, pressed)
        }
        if handlerOrder == .valueThenPressed, pressedChanged {
            storedPressedChangedHandler?(self, value, pressed)
        }
        return true
    }
}
