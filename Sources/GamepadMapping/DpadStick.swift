import Foundation

/// What a pad's D-pad drives on the synthesized gamepad. For pads with a D-pad and no
/// stick (8BitDo FlipPad and similar) in games that read only the stick.
@frozen public enum DpadMode: String, CaseIterable, Sendable {
    /// The D-pad, as on the pad.
    case dpad
    /// The left stick only; the synthesized D-pad stays at rest.
    case leftStick
    /// The D-pad and the left stick together, for games whose menus read one and
    /// whose gameplay reads the other.
    case both

    /// The mode a pad starts in when the app has not chosen one: both when the pad
    /// has no left stick of its own, otherwise the D-pad.
    public static func automatic(boundInputs: Set<GamepadInput>) -> DpadMode {
        boundInputs.contains(.dpad) && !boundInputs.contains(.leftThumbstick) ? .both : .dpad
    }

    /// The next mode in ``allCases`` order (or the previous one), wrapping round.
    public func cycled(forward: Bool = true) -> DpadMode {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + (forward ? 1 : all.count - 1)) % all.count]
    }

    public var drivesDpad: Bool { self != .leftStick }
    public var drivesStick: Bool { self != .dpad }
}

/// How far a held direction pushes the emulated stick.
@frozen public enum DpadStickResponse: Sendable, Equatable {
    /// Full deflection at once.
    case full
    /// Starts at `start` (0...1) and reaches full deflection after `duration` seconds
    /// of holding: a tap walks, a hold runs. Each axis ramps on its own, and
    /// reversing an axis starts its ramp again.
    case ramp(start: Float, duration: TimeInterval)

    /// A tap is 40%; full after a fifth of a second.
    public static let defaultRamp = DpadStickResponse.ramp(start: 0.4, duration: 0.2)
}

public struct DpadStickSettings: Sendable, Equatable {
    /// nil picks ``DpadMode/automatic(boundInputs:)`` for each pad.
    public var mode: DpadMode?
    public var response: DpadStickResponse
    /// A button that, while held, scales the emulated stick by ``modifierScale``
    /// (hold to walk). It still reaches the game as itself.
    public var modifier: GamepadInput?
    public var modifierScale: Float
    /// A button that, held, turns D-pad up / down into "next / previous mode" instead
    /// of a game input. nil for no quick toggle.
    public var modeChord: GamepadInput?

    public init(
        mode: DpadMode? = nil,
        response: DpadStickResponse = .full,
        modifier: GamepadInput? = nil,
        modifierScale: Float = 0.5,
        modeChord: GamepadInput? = nil
    ) {
        self.mode = mode
        self.response = response
        self.modifier = modifier
        self.modifierScale = modifierScale
        self.modeChord = modeChord
    }
}

/// Turns D-pad directions into left-stick values over time. Pure: the caller supplies
/// the clock, so it tests without one.
public struct DpadStickEmulator: Sendable {
    public var response: DpadStickResponse
    public var modifierScale: Float

    private var xDirection: Float = 0
    private var yDirection: Float = 0
    private var xSince: TimeInterval = 0
    private var ySince: TimeInterval = 0

    /// A direction counts as held past this value, as on the synthesized D-pad.
    public static let pressThreshold: Float = 0.5

    public init(response: DpadStickResponse = .full, modifierScale: Float = 0.5) {
        self.response = response
        self.modifierScale = modifierScale
    }

    /// Records the D-pad's position (x right, y up, -1...1) at `time`.
    public mutating func setDirection(x: Float, y: Float, at time: TimeInterval) {
        let newX = Self.digital(x), newY = Self.digital(y)
        if newX != xDirection {
            xDirection = newX
            xSince = time
        }
        if newY != yDirection {
            yDirection = newY
            ySince = time
        }
    }

    private static func digital(_ value: Float) -> Float {
        value > pressThreshold ? 1 : (value < -pressThreshold ? -1 : 0)
    }

    /// Whether any direction is held.
    public var isActive: Bool { xDirection != 0 || yDirection != 0 }

    /// Whether the stick value is still changing at `time`, so the caller must keep
    /// asking for it though no button has moved.
    public func isRamping(at time: TimeInterval) -> Bool {
        guard case let .ramp(_, duration) = response else { return false }
        return (xDirection != 0 && time - xSince < duration) || (yDirection != 0 && time - ySince < duration)
    }

    /// The stick at `time`. A diagonal is scaled back onto the unit circle, so
    /// up-right is not 141% deflection.
    public func stick(at time: TimeInterval, modifierHeld: Bool = false) -> (x: Float, y: Float) {
        var x = xDirection * magnitude(heldFor: time - xSince)
        var y = yDirection * magnitude(heldFor: time - ySince)
        let length = (x * x + y * y).squareRoot()
        if length > 1 {
            x /= length
            y /= length
        }
        let scale = modifierHeld ? max(0, min(1, modifierScale)) : 1
        return (x * scale, y * scale)
    }

    private func magnitude(heldFor elapsed: TimeInterval) -> Float {
        guard case let .ramp(start, duration) = response, duration > 0 else { return 1 }
        let progress = Float(max(0, min(1, elapsed / duration)))
        let floor = max(0, min(1, start))
        return floor + (1 - floor) * progress
    }
}
