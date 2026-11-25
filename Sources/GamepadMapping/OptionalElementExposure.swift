import Foundation

/// When a synthesized gamepad reports one of its optional buttons (Options, Home).
/// Apps key pause routes, default bindings and "missing button" UI off whether the
/// element is nil, and they disagree about what it should say.
@frozen public enum OptionalElementExposure: Sendable, Equatable {
    /// Always reported, bound or not.
    case always
    /// Reported when the physical pad has it.
    case whenBound
    /// Reported when the physical pad has it and it is not part of the pause trigger.
    case whenBoundAndNotPauseTrigger

    public func isExposed(_ input: GamepadInput, boundInputs: Set<GamepadInput>, pauseTrigger: PauseTrigger?) -> Bool {
        switch self {
        case .always: return true
        case .whenBound: return boundInputs.contains(input)
        case .whenBoundAndNotPauseTrigger:
            return boundInputs.contains(input) && pauseTrigger?.inputs.contains(input) != true
        }
    }
}
