import GameController
import GamepadKit
import XCTest

/// The wrapper end to end, against a fake pad, under each app's configuration.
final class PhysicalProfileControllerTests: XCTestCase {
    // MARK: iFly

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
