import GameController
@testable import GamepadKit
import XCTest

/// The wrapper end to end, against a fake pad, under each app's configuration.
final class PhysicalProfileControllerTests: XCTestCase {
    // MARK: iFly

    func testUnnamedPadIsNamedByItsProductCategory() {
        let hid = FakeController(vendorName: nil, productCategory: "HID")
        let unknown = FakeController(vendorName: nil, productCategory: "")
        XCTAssertEqual(PhysicalProfileController(wrapping: hid, configuration: AppConfigurations.iCube)
            .vendorName, "HID Gamepad")
        XCTAssertEqual(PhysicalProfileController(wrapping: unknown, configuration: AppConfigurations.iCube)
            .vendorName, "Unknown Controller")
    }

    func testAliasedButtonKeepsItsNamedInput() throws {
        let base = FakeController(vendorName: nil, productCategory: "HID",
                                  buttons: ["Button A", "Button 2"], dpads: ["Direction Pad"])
        base.profile.fakeButtons["Button 1"] = try XCTUnwrap(base.profile.fakeButtons["Button A"])
        let wrapper = PhysicalProfileController(wrapping: base, configuration: AppConfigurations.iCube)
        XCTAssertEqual(wrapper.bindings, ["Button A": .buttonA, "Button 2": .buttonB, "Direction Pad": .dpad])
        base.press("Button A")
        XCTAssertEqual(wrapper.extendedGamepad?.buttonA.isPressed, true)
        XCTAssertEqual(wrapper.extendedGamepad?.buttonB.isPressed, false)
    }

    func testPadNameOverridesThePadsOwnNameAndTheUnnamedFallback() {
        var configuration = AppConfigurations.iCube
        configuration.padName = { "Core name for \($0.productCategory)" }
        let named = FakeController(vendorName: "Odd Pad", productCategory: "HID")
        let unnamed = FakeController(vendorName: nil, productCategory: "HID")
        XCTAssertEqual(PhysicalProfileController(wrapping: named, configuration: configuration).vendorName,
                       "Core name for HID")
        XCTAssertEqual(PhysicalProfileController(wrapping: unnamed, configuration: configuration).vendorName,
                       "Core name for HID")
    }

    func testBindingsResolverReplacesTheMappingForWrappingAndBinding() {
        let base = FakeController(vendorName: "Odd Pad", productCategory: "HID",
                                  buttons: ["Fire", "Jump"], dpads: ["Stick"])
        var configuration = AppConfigurations.iCube
        XCTAssertEqual(PhysicalProfileController(wrapping: base, configuration: configuration).bindings["Jump"],
                       .buttonB, "the mapping alone takes Jump by position")
        configuration.bindingsResolver = { controller, family in
            XCTAssertEqual(controller.vendorName, "Odd Pad")
            XCTAssertEqual(family, .generic)
            return ["Fire": .buttonA, "Jump": .menu, "Stick": .dpad]
        }
        XCTAssertTrue(PhysicalProfileController.isNeeded(for: base, configuration: configuration))
        let wrapper = PhysicalProfileController(wrapping: base, configuration: configuration)
        XCTAssertEqual(wrapper.bindings, ["Fire": .buttonA, "Jump": .menu, "Stick": .dpad])
        XCTAssertEqual(wrapper.pauseTrigger, .button(.menu), "the pause policy reads the resolver's bindings")
        base.press("Fire")
        XCTAssertEqual(wrapper.extendedGamepad?.buttonA.isPressed, true)
    }

    func testIFlyShouldersDriveTheTriggersOnAPadWithoutThem() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iFly())
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        var shoulderValueEvents = 0, shoulderPressedEvents = 0
        gamepad.leftShoulder.valueChangedHandler = { _, _, _ in shoulderValueEvents += 1 }
        gamepad.leftShoulder.pressedChangedHandler = { _, _, _ in shoulderPressedEvents += 1 }

        pad.press("Left Shoulder")
        XCTAssertTrue(gamepad.leftTrigger.isPressed)
        XCTAssertEqual(gamepad.leftTrigger.value, 1, "a digital shoulder is a full trigger press")
        XCTAssertTrue(gamepad.leftShoulder.isPressed, "menus still see L")
        XCTAssertEqual(shoulderPressedEvents, 1)
        XCTAssertEqual(shoulderValueEvents, 0, "the core, on the value handler, must not see L1 (Dreamcast Z)")

        pad.press("Left Shoulder", false)
        XCTAssertFalse(gamepad.leftTrigger.isPressed)
        XCTAssertFalse(gamepad.leftShoulder.isPressed)
    }

    func testIFlySelectIsChordOnlyAndALoneTapIsReported() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iFly())
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        let taps = Counter(), pauses = Counter()
        wrapper.onSelectTap = { taps.count += 1 }
        wrapper.onPauseRequested = { pauses.triggers.append($0) }

        XCTAssertEqual(wrapper.pauseTrigger, .selectStart)
        XCTAssertNotNil(gamepad.buttonOptions, "always reported: flycast's Start placement keys off it")
        XCTAssertNil(gamepad.buttonHome)

        pad.press("Button Options")
        XCTAssertFalse(gamepad.buttonOptions!.isPressed, "Select never reaches the game")
        pad.press("Button Options", false)
        XCTAssertEqual(taps.count, 1)

        pad.press("Button Options")
        pad.press("Button A")
        pad.press("Button A", false)
        pad.press("Button Options", false)
        XCTAssertEqual(taps.count, 1, "another button in between is not a tap")
        XCTAssertTrue(pauses.triggers.isEmpty)
    }

    func testIFlySelectPlusStartPausesOnceAndHoldsStartBack() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iFly())
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        let taps = Counter(), pauses = Counter()
        wrapper.onSelectTap = { taps.count += 1 }
        wrapper.onPauseRequested = { pauses.triggers.append($0) }

        pad.press("Button Menu")
        XCTAssertTrue(gamepad.buttonMenu.isPressed, "Start alone reaches the game")
        pad.press("Button Options")
        XCTAssertEqual(pauses.triggers, [.selectStart])
        XCTAssertFalse(gamepad.buttonMenu.isPressed, "released to the game when the chord fires")

        pad.press("Button Menu", false)
        pad.press("Button Menu")
        XCTAssertFalse(gamepad.buttonMenu.isPressed, "held back until both are let go")
        XCTAssertEqual(pauses.triggers.count, 1)
        pad.press("Button Menu", false)
        pad.press("Button Options", false)
        XCTAssertEqual(taps.count, 0, "a chord is not a Select tap")

        pad.press("Button Menu")
        XCTAssertTrue(gamepad.buttonMenu.isPressed, "re-armed")
    }

    func testIFlyOnTVStartDrivesOptions() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iFly(isTV: true))
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        pad.press("Button Menu")
        XCTAssertTrue(gamepad.buttonOptions!.isPressed, "flycast's tvOS default has Dreamcast Start on Options")
        XCTAssertFalse(gamepad.buttonMenu.isPressed, "so the tvOS Menu pause never fires from Start")
    }

    func testIFlyHomeIsThePauseButtonAndIsHeldBack() throws {
        let pad = FakeController(
            vendorName: "N64 Controller", productCategory: "HID",
            buttons: ["A", "B", "Start", "ZR", "Home", "C Up", "C Left"], dpads: ["Joystick"]
        )
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iFly())
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        let pauses = Counter()
        wrapper.onPauseRequested = { pauses.triggers.append($0) }

        XCTAssertEqual(wrapper.pad, .n64)
        XCTAssertNil(gamepad.buttonHome, "not offered to the remap UI: it is the pause button")
        pad.press("Home")
        XCTAssertEqual(pauses.triggers, [.home])

        pad.press("C Up")
        pad.press("C Left")
        XCTAssertEqual(gamepad.rightThumbstick.xAxis.value, -1)
        XCTAssertEqual(gamepad.rightThumbstick.yAxis.value, 1)
        XCTAssertTrue(gamepad.rightThumbstick.up.isPressed)
        pad.press("C Up", false)
        XCTAssertEqual(gamepad.rightThumbstick.yAxis.value, 0)
    }

    // MARK: The same SNES pad, three apps

    /// The one mapping difference between iFly and Provenance: Provenance reads the
    /// SNES pad's system face names as printed labels, iFly as positions.
    func testSnesFaceButtonsDifferBetweenIFlyAndProvenance() throws {
        let iFlyPad = FakeController.snes(), provenancePad = FakeController.snes()
        let iFly = PhysicalProfileController(wrapping: iFlyPad, configuration: AppConfigurations.iFly())
        let provenance = PhysicalProfileController(wrapping: provenancePad, configuration: AppConfigurations.provenance)

        iFlyPad.press("Button A")
        XCTAssertTrue(iFly.extendedGamepad!.buttonA.isPressed)
        provenancePad.press("Button A")
        XCTAssertTrue(provenance.extendedGamepad!.buttonB.isPressed, "printed A is the right-hand button")
        XCTAssertFalse(provenance.extendedGamepad!.buttonA.isPressed)
    }

    func testProvenanceStartAndSelectReachTheGameAndTheChordFiresThePausedHandler() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.provenance)
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        var paused = 0
        wrapper.controllerPausedHandler = { _ in paused += 1 }

        pad.press("Left Shoulder")
        XCTAssertTrue(gamepad.leftShoulder.isPressed, "no re-routing")
        XCTAssertFalse(gamepad.leftTrigger.isPressed)

        pad.press("Button Options")
        XCTAssertTrue(gamepad.buttonOptions!.isPressed, "Select alone is a game button")
        XCTAssertEqual(paused, 0)
        pad.press("Button Menu")
        XCTAssertEqual(paused, 1)
        XCTAssertFalse(gamepad.buttonOptions!.isPressed, "released when the chord fires")
        XCTAssertFalse(gamepad.buttonMenu.isPressed)
    }

    func testICubeChordPausesWithoutHoldingAnythingBack() throws {
        let pad = FakeController.snes()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iCube)
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        let pauses = Counter()
        var legacy = 0
        wrapper.onPauseRequested = { pauses.triggers.append($0) }
        wrapper.controllerPausedHandler = { _ in legacy += 1 }

        XCTAssertNil(gamepad.buttonOptions, "Select alone must not pause through the Options route")
        pad.press("Button Options")
        pad.press("Button Menu")
        XCTAssertEqual(pauses.triggers, [.selectStart])
        XCTAssertEqual(legacy, 0, "the paused handler is Home's")
        XCTAssertTrue(gamepad.buttonMenu.isPressed, "Start still reaches the game")

        pad.playerIndex = .index2
        XCTAssertEqual(wrapper.playerIndex, .index2,
                       "iCube writes the index on the real pad and reads it through the wrapper")
    }

    func testICubePadWithOnlyStartPausesFromItAndStillPlays() throws {
        let pad = FakeController(vendorName: "N64 Controller", productCategory: "HID",
                                 buttons: ["A", "B", "Start"], dpads: ["Direction Pad"])
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.iCube)
        let pauses = Counter()
        wrapper.onPauseRequested = { pauses.triggers.append($0) }
        pad.press("Start")
        XCTAssertEqual(pauses.triggers, [.button(.menu)])
        XCTAssertTrue(wrapper.extendedGamepad!.buttonMenu.isPressed)
    }

    // MARK: Generic pads

    func testGenericPadBindsByPositionAndDrivesTriggersFromAxes() throws {
        let pad = FakeController(
            vendorName: nil, productCategory: "HID",
            buttons: (1 ... 4).map { "Button \($0)" }, dpads: ["Direction Pad", "Left Thumbstick"],
            axes: ["Left Trigger", "Right Trigger"]
        )
        let configuration = AppConfigurations.iFly()
        XCTAssertTrue(PhysicalProfileController.isNeeded(for: pad, configuration: configuration))
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: configuration)
        let gamepad = try XCTUnwrap(wrapper.extendedGamepad)
        XCTAssertEqual(wrapper.vendorName, "HID Gamepad", "an unnamed pad gets its own mapping file")

        pad.press("Button 1")
        XCTAssertTrue(gamepad.buttonA.isPressed)

        pad.profile.fakeDpads["Left Thumbstick"]!.update(x: 0.75, y: -1)
        XCTAssertEqual(gamepad.leftThumbstick.xAxis.value, 0.75)
        XCTAssertTrue(gamepad.leftThumbstick.down.isPressed)

        let axis = pad.profile.fakeAxes["Right Trigger"]!
        axis.update(0.5)
        XCTAssertEqual(gamepad.rightTrigger.value, 0.5, "an axis that rests at 0")
        XCTAssertTrue(gamepad.rightTrigger.isPressed)
        axis.update(-1)
        XCTAssertEqual(gamepad.rightTrigger.value, 0, "seen below zero: it rests at -1")
        axis.update(0)
        XCTAssertEqual(gamepad.rightTrigger.value, 0.5, "and its midpoint is a half press")
    }

    func testWhichPadsAreWrapped() {
        let remote = FakeController(vendorName: "Remote", productCategory: "Siri Remote (2nd Generation)",
                                    buttons: ["Button A", "Button X", "Button Menu"], dpads: ["Direction Pad"])
        let hid = FakeController(vendorName: "8BitDo FlipPad", productCategory: "HID",
                                 buttons: ["Button A", "Button B"], dpads: ["Direction Pad"])
        let useless = FakeController(vendorName: "Dial", productCategory: "HID", buttons: ["Button A"])
        for configuration in [AppConfigurations.iFly(), AppConfigurations.provenance, AppConfigurations.iCube] {
            XCTAssertFalse(PhysicalProfileController.isNeeded(for: remote, configuration: configuration))
            XCTAssertTrue(PhysicalProfileController.isNeeded(for: hid, configuration: configuration))
            XCTAssertFalse(PhysicalProfileController.isNeeded(for: useless, configuration: configuration))
            let wrapper = PhysicalProfileController(wrapping: hid, configuration: configuration)
            XCTAssertFalse(PhysicalProfileController.isNeeded(for: wrapper, configuration: configuration),
                           "a wrapper is never wrapped again")
        }
    }

    // MARK: Lifetime

    func testRegistrySubstitutesWrappersAndUnbindStopsInput() throws {
        let pad = FakeController.snes()
        let other = FakeController.snes()
        let registry = PhysicalProfileControllerRegistry()
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: AppConfigurations.provenance)
        registry.register(wrapper)

        XCTAssertTrue(registry.wrapper(for: pad) === wrapper)
        XCTAssertNil(registry.wrapper(for: other))
        let substituted = registry.substituting([other, pad])
        XCTAssertTrue(substituted[0] === other)
        XCTAssertTrue(substituted[1] === wrapper)
        XCTAssertTrue(PhysicalProfileControllerRegistry.base(of: wrapper) === pad)

        wrapper.playerIndex = .index1
        XCTAssertEqual(pad.playerIndex, .index1)

        XCTAssertTrue(registry.remove(base: pad) === wrapper)
        wrapper.unbind()
        pad.press("Button B")
        XCTAssertFalse(wrapper.extendedGamepad!.buttonA.isPressed)
        XCTAssertTrue(registry.substituting([pad])[0] === pad)
    }
}

/// A clock a test can move.
final class TestClock: @unchecked Sendable {
    var now: TimeInterval = 100
}

/// D-pad-as-stick, for a pad with a D-pad and no stick.
final class DpadStickControllerTests: XCTestCase {
    private func flipPad() -> FakeController {
        FakeController(vendorName: "8BitDo FlipPad", productCategory: "HID",
                       buttons: ["Button A", "Button B", "Left Shoulder", "Button Options", "Button Menu"],
                       dpads: ["Direction Pad"])
    }

    private func wrapper(
        _ pad: FakeController,
        _ settings: DpadStickSettings?,
        clock: TestClock = TestClock()
    ) -> PhysicalProfileController {
        var configuration = AppConfigurations.iFly()
        configuration.dpadStick = settings
        let wrapper = PhysicalProfileController(wrapping: pad, configuration: configuration)
        wrapper.clock = { clock.now }
        return wrapper
    }

    private func move(_ pad: FakeController, x: Float, y: Float) {
        pad.profile.fakeDpads["Direction Pad"]!.update(x: x, y: y)
    }

    func testWithoutTheSettingTheDpadIsOnlyADpad() {
        let pad = flipPad()
        let wrapper = wrapper(pad, nil)
        move(pad, x: 1, y: 0)
        XCTAssertEqual(wrapper.dpadMode, .dpad)
        XCTAssertTrue(wrapper.synthesized.dpad.right.isPressed)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0)
        wrapper.dpadMode = .both
        XCTAssertEqual(wrapper.dpadMode, .dpad, "the mode cannot be set while the feature is off")
    }

    func testAPadWithNoStickStartsInBothAndDrivesTheStickOnTheUnitCircle() {
        let pad = flipPad()
        let wrapper = wrapper(pad, DpadStickSettings())
        XCTAssertEqual(wrapper.dpadMode, .both)
        var stickEvents = 0
        wrapper.synthesized.leftThumbstick.valueChangedHandler = { _, _, _ in stickEvents += 1 }

        move(pad, x: 1, y: 1)
        XCTAssertTrue(wrapper.synthesized.dpad.up.isPressed)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0.7071, accuracy: 0.001)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.yAxis.value, 0.7071, accuracy: 0.001)
        XCTAssertEqual(stickEvents, 1)

        move(pad, x: 0, y: 0)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0)
        XCTAssertFalse(wrapper.synthesized.dpad.up.isPressed)
    }

    func testStickOnlyModeLeavesTheDpadAtRest() {
        let pad = flipPad()
        let wrapper = wrapper(pad, DpadStickSettings(mode: .leftStick))
        move(pad, x: -1, y: 0)
        XCTAssertFalse(wrapper.synthesized.dpad.left.isPressed)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, -1)
    }

    func testAPadWithItsOwnStickKeepsIt() {
        let pad = FakeController(vendorName: nil, productCategory: "HID", buttons: ["Button A"],
                                 dpads: ["Direction Pad", "Left Thumbstick"])
        let wrapper = wrapper(pad, DpadStickSettings())
        XCTAssertEqual(wrapper.dpadMode, .dpad, "automatic leaves a pad with a stick alone")
        pad.profile.fakeDpads["Left Thumbstick"]!.update(x: 0.3, y: 0)
        move(pad, x: 1, y: 0)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0.3)
    }

    func testSelectPlusDpadCyclesTheModeWithoutReachingTheGameOrCountingAsATap() {
        let pad = flipPad()
        let wrapper = wrapper(pad, DpadStickSettings(modeChord: .options))
        let modes = Counter(), taps = Counter()
        var seen: [DpadMode] = []
        wrapper.onDpadModeChanged = { _ in modes.count += 1 }
        wrapper.onSelectTap = { taps.count += 1 }

        pad.press("Button Options")
        move(pad, x: 0, y: 1)
        seen.append(wrapper.dpadMode)
        XCTAssertFalse(wrapper.synthesized.dpad.up.isPressed, "the game sees a D-pad at rest")
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.yAxis.value, 0)
        move(pad, x: 0, y: 0)
        move(pad, x: 0, y: 1)
        seen.append(wrapper.dpadMode)
        move(pad, x: 0, y: 0)
        move(pad, x: 0, y: -1)
        seen.append(wrapper.dpadMode)
        move(pad, x: 0, y: 0)
        pad.press("Button Options", false)

        XCTAssertEqual(seen, [.dpad, .leftStick, .dpad], "from both: up, up, then down")
        XCTAssertEqual(modes.count, 3)
        XCTAssertEqual(taps.count, 0, "Select used for the chord is not Insert Coin")
    }

    func testLettingGoOfTheChordHandsAHeldDirectionBackToTheGame() {
        let pad = flipPad()
        let wrapper = wrapper(pad, DpadStickSettings(mode: .dpad, modeChord: .options))
        move(pad, x: 1, y: 0)
        pad.press("Button Options")
        move(pad, x: 1, y: 0.1)
        XCTAssertFalse(wrapper.synthesized.dpad.right.isPressed)
        pad.press("Button Options", false)
        XCTAssertTrue(wrapper.synthesized.dpad.right.isPressed)
    }

    func testRampAdvancesOnTicks() {
        let pad = flipPad()
        let clock = TestClock()
        let wrapper = wrapper(pad, DpadStickSettings(mode: .leftStick, response: .ramp(start: 0.4, duration: 0.2)),
                              clock: clock)
        move(pad, x: 1, y: 0)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0.4, accuracy: 0.001)
        clock.now += 0.1
        wrapper.tick()
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0.7, accuracy: 0.001)
        clock.now += 0.5
        wrapper.tick()
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 1, accuracy: 0.001)
        move(pad, x: 0, y: 0)
        wrapper.tick()
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.xAxis.value, 0)
        wrapper.unbind()
    }

    func testModifierHalvesTheStickWhileHeldAndStillReachesTheGame() {
        let pad = flipPad()
        // iFly routes a shoulder to the trigger on this pad; the modifier is the physical button.
        let wrapper = wrapper(pad, DpadStickSettings(mode: .leftStick, modifier: .leftShoulder))
        move(pad, x: 0, y: -1)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.yAxis.value, -1)
        pad.press("Left Shoulder")
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.yAxis.value, -0.5)
        XCTAssertTrue(wrapper.synthesized.leftTrigger.isPressed)
        pad.press("Left Shoulder", false)
        XCTAssertEqual(wrapper.synthesized.leftThumbstick.yAxis.value, -1)
    }
}
