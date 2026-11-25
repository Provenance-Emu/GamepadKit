import Foundation

/// What opens an app's pause menu on a synthesized pad.
@frozen public enum PauseTrigger: Equatable, Sendable {
    /// The pad's Home button.
    case home
    /// Every input in the set held at once.
    case chord(Set<GamepadInput>)
    /// One ordinary button, for a pad that would otherwise have no way to pause. The
    /// button still reaches the game; the pause stops emulation right after.
    case button(GamepadInput)

    /// Select + Start, the pause chord for pads with no Home button.
    public static let selectStartChord: Set<GamepadInput> = [.options, .menu]
    /// ``chord(_:)`` of ``selectStartChord``.
    public static let selectStart = PauseTrigger.chord(selectStartChord)

    /// Whether `pressed` completes this trigger.
    public func isSatisfied(by pressed: Set<GamepadInput>) -> Bool {
        switch self {
        case .home: return pressed.contains(.home)
        case let .chord(inputs): return !inputs.isEmpty && inputs.isSubset(of: pressed)
        case let .button(input): return pressed.contains(input)
        }
    }

    /// Inputs that belong to the trigger.
    public var inputs: Set<GamepadInput> {
        switch self {
        case .home: return [.home]
        case let .chord(inputs): return inputs
        case let .button(input): return [input]
        }
    }

    /// Whether the trigger's inputs can be held back from the game once it fires.
    /// False for ``button(_:)``, whose button is a game button first.
    public var canHoldBackInputs: Bool {
        if case .button = self { return false }
        return true
    }
}

/// How an app picks the ``PauseTrigger`` of a synthesized pad.
@frozen public enum PausePolicy: Sendable, Equatable {
    /// Home when the pad has one, otherwise Select + Start held together; nil when it
    /// has neither. Provenance and iFly.
    ///
    /// The Switch Online SNES pad is the chord case. Apple's profile for it
    /// (`_GCNintendoSuperFamicomControllerProfile`, iOS 26 / tvOS 27) exposes only
    /// A, B, X, Y, L, R, Start ("Button Menu"), Select ("Button Options") and the
    /// D-pad: no Home, and no ZL/ZR although the pad has them.
    case homeOrSelectStart
    /// Home when the pad has one; Select + Start for the SNES family only; Start alone
    /// for a pad with no Options, so no pad is left unable to pause; otherwise nil,
    /// which leaves pausing to the app's extended-gamepad routes (Options alone, as
    /// on the N64 pad's ZR). iCube.
    case homeSnesChordOrStart

    public func trigger(forBindings bindings: [String: GamepadInput], family: PadFamily = .generic) -> PauseTrigger? {
        let inputs = Set(bindings.values)
        if inputs.contains(.home) { return .home }
        switch self {
        case .homeOrSelectStart:
            return PauseTrigger.selectStartChord.isSubset(of: inputs) ? .selectStart : nil
        case .homeSnesChordOrStart:
            if family == .snes, PauseTrigger.selectStartChord.isSubset(of: inputs) { return .selectStart }
            if !inputs.contains(.options), inputs.contains(.menu) { return .button(.menu) }
            return nil
        }
    }
}

/// Follows button transitions and says when a ``PauseTrigger`` fires. It fires once,
/// when the input that completes it goes down, and again only after every one of its
/// inputs has been released.
public struct PauseTriggerTracker: Sendable {
    @frozen public enum Outcome: Equatable, Sendable {
        /// Not part of a fired trigger: pass the transition on.
        case forward
        /// This press completed the trigger.
        case fired
        /// The trigger has fired and this input belongs to it; it stays released to
        /// the game until every trigger input is let go (if the app holds them back).
        case latched
    }

    public let trigger: PauseTrigger?
    /// Buttons currently held, before the trigger filters them.
    public private(set) var held: Set<GamepadInput> = []
    /// Set once the trigger fires, until all of its inputs are released.
    public private(set) var isLatched = false

    public init(trigger: PauseTrigger?) {
        self.trigger = trigger
    }

    /// Whether `input` was held before the next ``update(_:pressed:)``.
    public func isHeld(_ input: GamepadInput) -> Bool { held.contains(input) }

    public mutating func update(_ input: GamepadInput, pressed: Bool) -> Outcome {
        let wasHeld = held.contains(input)
        if pressed { held.insert(input) } else { held.remove(input) }
        guard let trigger else { return .forward }
        if isLatched {
            if held.isDisjoint(with: trigger.inputs) { isLatched = false }
            return trigger.inputs.contains(input) ? .latched : .forward
        }
        if pressed, !wasHeld, trigger.isSatisfied(by: held) {
            isLatched = true
            return .fired
        }
        return .forward
    }
}

/// Detects a tap of one button on its own: pressed with nothing else held, released
/// with nothing else pressed in between. iFly uses it for chord-only Select, which has
/// no game function on the Dreamcast, as Insert Coin on arcade boards.
public struct LoneTapTracker: Sendable {
    public let input: GamepadInput
    private var pending = false

    public init(input: GamepadInput) {
        self.input = input
    }

    /// Records a transition; true when it completes a lone tap of ``input``.
    /// - Parameters:
    ///   - wasHeld: whether `changed` was held before this transition.
    ///   - held: everything held after it.
    public mutating func update(
        _ changed: GamepadInput,
        pressed: Bool,
        wasHeld: Bool,
        held: Set<GamepadInput>
    ) -> Bool {
        guard changed == input else {
            if pressed { pending = false }
            return false
        }
        if pressed, !wasHeld {
            pending = held == [input]
        } else if !pressed, wasHeld, pending {
            pending = false
            return true
        }
        return false
    }

    /// Drops a pending tap (the button turned out to be part of a chord).
    public mutating func cancel() { pending = false }
}
