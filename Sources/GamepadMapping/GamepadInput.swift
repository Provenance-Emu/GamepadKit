import Foundation

/// One input of the extended gamepad a physical input profile is mapped onto.
///
/// The raw values are stable: apps log them and may store them.
public enum GamepadInput: String, CaseIterable, Sendable {
    case dpad, leftThumbstick, rightThumbstick
    case buttonA, buttonB, buttonX, buttonY
    case leftShoulder, rightShoulder, leftTrigger, rightTrigger
    case menu, options, home
    /// Stick clicks (L3/R3).
    case leftThumbstickButton, rightThumbstickButton
    /// Digital buttons that stand in for the right thumbstick: the N64 C cluster.
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight

    /// A direction pad or a thumbstick.
    public var isDirection: Bool {
        switch self {
        case .dpad, .leftThumbstick, .rightThumbstick: return true
        default: return false
        }
    }

    /// One direction of the N64 C cluster.
    public var isCButton: Bool {
        switch self {
        case .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight: return true
        default: return false
        }
    }

    public static let faceButtons: Set<GamepadInput> = [.buttonA, .buttonB, .buttonX, .buttonY]
    public static let triggers: Set<GamepadInput> = [.leftTrigger, .rightTrigger]
}
