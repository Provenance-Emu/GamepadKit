import GameController

/// An axis whose value is set from code. Some cores hook the thumbstick axes'
/// `valueChangedHandler` directly, so it is stored and fired.
public final class SynthesizedAxisInput: GCControllerAxisInput, @unchecked Sendable {
    private var storedValue: Float = 0
    private var storedValueChangedHandler: GCControllerAxisValueChangedHandler?

    override public var value: Float { storedValue }

    override public var valueChangedHandler: GCControllerAxisValueChangedHandler? {
        get { storedValueChangedHandler }
        set { storedValueChangedHandler = newValue }
    }

    /// - Returns: whether the value changed.
    @discardableResult
    public func update(_ value: Float) -> Bool {
        guard value != storedValue else { return false }
        storedValue = value
        storedValueChangedHandler?(self, value)
        return true
    }
}
