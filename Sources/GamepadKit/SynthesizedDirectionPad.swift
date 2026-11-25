import GameController

/// A direction pad (or thumbstick) whose state is set from code.
public final class SynthesizedDirectionPad: GCControllerDirectionPad, @unchecked Sendable {
    private let synthesizedXAxis = SynthesizedAxisInput()
    private let synthesizedYAxis = SynthesizedAxisInput()
    private let synthesizedUp = SynthesizedButtonInput()
    private let synthesizedDown = SynthesizedButtonInput()
    private let synthesizedLeft = SynthesizedButtonInput()
    private let synthesizedRight = SynthesizedButtonInput()
    private var storedValueChangedHandler: GCControllerDirectionPadValueChangedHandler?

    /// Handler order of the four direction buttons.
    public var buttonHandlerOrder: SynthesizedButtonInput.HandlerOrder = .valueThenPressed {
        didSet {
            for button in [synthesizedUp, synthesizedDown, synthesizedLeft, synthesizedRight] {
                button.handlerOrder = buttonHandlerOrder
            }
        }
    }

    override public var xAxis: GCControllerAxisInput { synthesizedXAxis }
    override public var yAxis: GCControllerAxisInput { synthesizedYAxis }
    override public var up: GCControllerButtonInput { synthesizedUp }
    override public var down: GCControllerButtonInput { synthesizedDown }
    override public var left: GCControllerButtonInput { synthesizedLeft }
    override public var right: GCControllerButtonInput { synthesizedRight }

    override public var valueChangedHandler: GCControllerDirectionPadValueChangedHandler? {
        get { storedValueChangedHandler }
        set { storedValueChangedHandler = newValue }
    }

    /// Sets the pad from axis values in -1...1 (y up). The four direction buttons
    /// (digital at 0.5) update BEFORE the pad handler fires, because a core's pad
    /// handler may read `up/down/left/right.isPressed`.
    /// - Returns: whether anything changed.
    @discardableResult
    public func update(x: Float, y: Float) -> Bool {
        var changed = synthesizedXAxis.update(x)
        changed = synthesizedYAxis.update(y) || changed
        changed = synthesizedUp.update(value: max(0, y), pressed: y > 0.5) || changed
        changed = synthesizedDown.update(value: max(0, -y), pressed: y < -0.5) || changed
        changed = synthesizedLeft.update(value: max(0, -x), pressed: x < -0.5) || changed
        changed = synthesizedRight.update(value: max(0, x), pressed: x > 0.5) || changed
        guard changed else { return false }
        storedValueChangedHandler?(self, x, y)
        return true
    }
}
