import GamepadKit

/// The configuration each app would pass to reproduce what its own copy of the
/// wrapper does today. They live in the tests, not the library: the package ships no
/// app's behaviour, and these are what the adoption PRs would move into each app.
enum AppConfigurations {
    /// iFly (`Sources/Core/Input/PhysicalProfile`, 506a2b1cd).
    /// - Parameter isTV: iFly compiles this in with `#if os(tvOS)`.
    static func iFly(isTV: Bool = false) -> PhysicalProfileConfiguration {
        PhysicalProfileConfiguration(
            mapping: PhysicalProfileMapping(table: .retroPadSystemFaces),
            wrapPolicy: .anyUsablePad,
            pausePolicy: .homeOrSelectStart,
            router: dreamcastRouter(isTV: isTV),
            holdsBackPauseInputs: true,
            // flycast's default Start placement keys off Options being there.
            optionsExposure: .always,
            homeExposure: .whenBoundAndNotPauseTrigger,
            systemGestureDisabledInputs: [.menu, .options, .home],
            legacyPausedHandler: .never,
            buttonHandlerOrder: .valueThenPressed,
            playerIndexStorage: .wrapperForwardingToBase,
            // iFly's own text; an empty category gives " Gamepad" there.
            unnamedPadName: { "\($0) Gamepad" }
        )
    }

    /// iFly's Dreamcast routing:
    /// - **Shoulders → triggers** on a pad with no ZL/ZR: flycast's default mapping
    ///   sends L2/R2 to the Dreamcast analog triggers, and L1/R1 to Z/C, buttons a
    ///   6-button pad has and this one doesn't. The shoulder still reports to
    ///   pressed-handler listeners, which is how the library cycles systems on L/R.
    /// - **Select is chord-only** when it is part of the pause chord, and never
    ///   reaches flycast (the Dreamcast has no Select).
    /// - **Start → Dreamcast Start on both platforms.** flycast's default puts DC
    ///   Start on Menu on iOS but on Options on tvOS, so on tvOS Start drives Options
    ///   and a lone Select stands in for the tvOS Menu pause.
    /// - **Home is the pause button** when the pad has one, and is held back.
    static func dreamcastRouter(isTV: Bool) -> InputRouter {
        InputRouter { input, context in
            switch input {
            case .options:
                if context.pauseTrigger?.inputs.contains(.options) == true { return nil }
                return InputRoute(target: isTV ? .menu : .options)
            case .menu:
                return InputRoute(target: isTV ? .options : .menu)
            case .home:
                return context.pauseTrigger == .home ? nil : InputRoute(target: .home)
            case .leftShoulder:
                return context.boundInputs.contains(.leftTrigger)
                    ? InputRoute(target: .leftShoulder)
                    : InputRoute(target: .leftTrigger, pressedOnlyMirror: .leftShoulder)
            case .rightShoulder:
                return context.boundInputs.contains(.rightTrigger)
                    ? InputRoute(target: .rightShoulder)
                    : InputRoute(target: .rightTrigger, pressedOnlyMirror: .rightShoulder)
            default:
                return InputRoute(target: input)
            }
        }
    }

    /// Provenance (`PVSupport/Controller/PhysicalProfile`, the generic-pad port in progress).
    static let provenance = PhysicalProfileConfiguration(
        mapping: PhysicalProfileMapping(table: .retroPad),
        wrapPolicy: .usablePadNotRemoteLike,
        pausePolicy: .homeOrSelectStart,
        router: .identity,
        holdsBackPauseInputs: true,
        optionsExposure: .whenBound,
        homeExposure: .whenBound,
        systemGestureDisabledInputs: [.menu, .options],
        legacyPausedHandler: .anyTrigger,
        playerIndexStorage: .wrapperForwardingToBase
    )

    /// iCube (`Controllers/PhysicalProfile`, develop aa9ff9ac13 plus the generic-pad port in progress).
    static let iCube = PhysicalProfileConfiguration(
        mapping: PhysicalProfileMapping(table: .gameCube),
        wrapPolicy: .switchOnlineOrProfileOnly,
        pausePolicy: .homeSnesChordOrStart,
        router: .identity,
        holdsBackPauseInputs: false,
        optionsExposure: .whenBoundAndNotPauseTrigger,
        homeExposure: .whenBound,
        systemGestureDisabledInputs: Set(GamepadInput.allCases),
        legacyPausedHandler: .homeOnly,
        buttonHandlerOrder: .pressedThenValue,
        playerIndexStorage: .base,
        // The name iCube's core gives the same pad (`MFiController::GetName`).
        unnamedPadName: { category in
            category.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown Controller" : "\(category) Gamepad"
        }
    )
}
