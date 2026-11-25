import Foundation

/// What a router may look at when deciding where a physical input lands.
public struct RoutingContext: Sendable, Equatable {
    /// Every input the pad's bindings resolved to.
    public var boundInputs: Set<GamepadInput>
    public var pauseTrigger: PauseTrigger?
    public var family: PadFamily

    public init(boundInputs: Set<GamepadInput>, pauseTrigger: PauseTrigger?, family: PadFamily) {
        self.boundInputs = boundInputs
        self.pauseTrigger = pauseTrigger
        self.family = family
    }
}

/// Where a physical button lands on the synthesized gamepad.
public struct InputRoute: Sendable, Equatable {
    /// The synthesized element the button drives. A digital button routed to a
    /// trigger it is not is a full press.
    public var target: GamepadInput
    /// A second element that reports the press to `pressedChangedHandler` listeners
    /// only, never to `valueChangedHandler` ones. iFly uses it for a shoulder routed
    /// to a trigger: its menus still see L/R, while the core (which hooks the value
    /// handler) must not also see L1/R1.
    public var pressedOnlyMirror: GamepadInput?

    public init(target: GamepadInput, pressedOnlyMirror: GamepadInput? = nil) {
        self.target = target
        self.pressedOnlyMirror = pressedOnlyMirror
    }
}

/// The per-app step between a pad's bindings and the synthesized gamepad: re-routes a
/// button to another element, or holds it back from the game (nil). Applies to button
/// inputs only; directions and the C cluster always drive their own element.
public struct InputRouter: Sendable {
    public var route: @Sendable (GamepadInput, RoutingContext) -> InputRoute?

    public init(route: @escaping @Sendable (GamepadInput, RoutingContext) -> InputRoute?) {
        self.route = route
    }

    /// Every button drives the element of the same name. Provenance and iCube.
    public static let identity = InputRouter { input, _ in InputRoute(target: input) }
}
