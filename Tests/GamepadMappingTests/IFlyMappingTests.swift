import GamepadMapping
import XCTest

/// Element-name mapping behind the Switch Online pad wrapper. Pure strings.
final class IFlyMappingTests: XCTestCase {
    private let mapping = PhysicalProfileMapping(table: .retroPadSystemFaces)

    /// What Apple's `_GCNintendoSuperFamicomControllerProfile` exposes (iOS 26 / tvOS 27).
    private let snesElements = [
        "Button A", "Button B", "Button X", "Button Y", "Left Shoulder", "Right Shoulder",
        "Button Menu", "Button Options", "Direction Pad"
    ]

    func testDetectsTheSNESPadFromVendorAndCategory() {
        let detect = PadFamily.detect(vendorName:productCategory:)
        XCTAssertEqual(detect("SNES Controller", "Switch SNES Controller"), .snes)
        XCTAssertEqual(detect("N64 Controller", nil), .n64)
        XCTAssertEqual(detect("Xbox Wireless Controller", "Xbox One"), .generic)
        XCTAssertFalse(PadFamily.generic.isSwitchOnline)
        XCTAssertTrue(PadFamily.snes.isSwitchOnline)
    }

    func testSNESProfileBindsEveryElementToItsStandardInput() {
        let bindings = mapping.bindings(forElementNames: snesElements, pad: .snes)
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertEqual(bindings["Button B"], .buttonB)
        XCTAssertEqual(bindings["Button X"], .buttonX)
        XCTAssertEqual(bindings["Button Y"], .buttonY)
        XCTAssertEqual(bindings["Left Shoulder"], .leftShoulder)
        XCTAssertEqual(bindings["Right Shoulder"], .rightShoulder)
        XCTAssertEqual(bindings["Button Menu"], .menu)
        XCTAssertEqual(bindings["Button Options"], .options)
        XCTAssertEqual(bindings["Direction Pad"], .dpad)
        XCTAssertEqual(bindings.count, snesElements.count)
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: bindings))
    }

    func testSNESPadPausesOnSelectPlusStart() {
        let bindings = mapping.bindings(forElementNames: snesElements, pad: .snes)
        let trigger = PausePolicy.homeOrSelectStart.trigger(forBindings: bindings)
        XCTAssertEqual(trigger, .chord([.options, .menu]))
        XCTAssertFalse(trigger?.isSatisfied(by: [.menu]) ?? true)
        XCTAssertFalse(trigger?.isSatisfied(by: [.options]) ?? true)
        XCTAssertTrue(trigger?.isSatisfied(by: [.options, .menu, .buttonA]) ?? false)
    }

    func testHomeWinsOverTheChord() {
        let bindings = mapping.bindings(
            forElementNames: snesElements + ["Button Home"], pad: .snes
        )
        XCTAssertEqual(PausePolicy.homeOrSelectStart.trigger(forBindings: bindings), .home)
    }

    func testStandardNamesWinOverAliasesForTheSameInput() {
        // "Button 1" is SNES A → buttonB through the HID table; "Button B" is the
        // system's own name for buttonB and must keep it.
        let bindings = mapping.bindings(forElementNames: ["Button 1", "Button B"], pad: .snes)
        XCTAssertEqual(bindings["Button B"], .buttonB)
        XCTAssertNil(bindings["Button 1"])
    }

    func testPrintedLabelsAndHIDIndicesResolvePerFamily() {
        XCTAssertEqual(mapping.input(forElementNamed: "Select", pad: .snes), .options)
        XCTAssertEqual(mapping.input(forElementNamed: "ZL", pad: .snes), .leftTrigger)
        XCTAssertEqual(mapping.input(forElementNamed: "Button 9", pad: .snes), .menu)
        XCTAssertEqual(mapping.input(forElementNamed: "C-Up", pad: .n64), .rightStickUp)
        XCTAssertEqual(mapping.input(forElementNamed: "Button 6", pad: .n64), .leftTrigger)
        XCTAssertNil(mapping.input(forElementNamed: "Button 40", pad: .snes))
    }

    func testAProfileWithoutDirectionsIsNotUsable() {
        let bindings = mapping.bindings(forElementNames: ["Button A", "Button Menu"], pad: .snes)
        XCTAssertFalse(PhysicalProfileMapping.isUsable(bindings: bindings))
    }

    // MARK: Generic HID pads

    func testNumberedButtonsAndAnUnnamedDirectionFillInputsInOrder() {
        let buttons = (1 ... 13).map { "Button \($0)" }
        let bindings = mapping.genericBindings(buttonNames: buttons, directionNames: ["Hat Switch"])
        XCTAssertEqual(bindings["Hat Switch"], .dpad)
        XCTAssertEqual(bindings["Button 1"], .buttonA)
        XCTAssertEqual(bindings["Button 2"], .buttonB)
        XCTAssertEqual(bindings["Button 4"], .buttonY)
        XCTAssertEqual(bindings["Button 9"], .options)
        XCTAssertEqual(bindings["Button 10"], .menu)
        XCTAssertEqual(bindings["Button 11"], .leftThumbstickButton)
        XCTAssertEqual(bindings["Button 12"], .rightThumbstickButton)
        XCTAssertNil(bindings["Button 13"])
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: bindings))
    }

    func testNamedElementsKeepTheirInputAndDirectionHalvesAreNotButtons() {
        let bindings = mapping.genericBindings(
            buttonNames: [
                "Button A", "Button B", "Button Menu", "Direction Pad Up", "Direction Pad Left",
                "Left Thumbstick Button", "Button Share"
            ],
            directionNames: ["Direction Pad", "Left Thumbstick"]
        )
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertEqual(bindings["Direction Pad"], .dpad)
        XCTAssertEqual(bindings["Left Thumbstick"], .leftThumbstick)
        XCTAssertNil(bindings["Direction Pad Up"])
        XCTAssertEqual(bindings["Left Thumbstick Button"], .leftThumbstickButton)
        // A named extra is left alone once the names gave a face button.
        XCTAssertNil(bindings["Button Share"])
    }

    func testOddlyNamedButtonsAreTakenWhenNamesGiveNoFaceButton() {
        let bindings = mapping.genericBindings(
            buttonNames: ["Fire", "Jump"], directionNames: ["Direction Pad"]
        )
        XCTAssertEqual(Set(bindings.values), [.dpad, .buttonA, .buttonB])
    }

    func testATriggerAxisTakesTheTriggerOnlyWhenNoButtonDid() {
        let named = mapping.genericBindings(
            buttonNames: ["Button A", "Button B"],
            directionNames: ["Direction Pad"],
            axisNames: ["Left Trigger", "R2", "Left Thumbstick X Axis"]
        )
        XCTAssertEqual(named["Left Trigger"], .leftTrigger)
        XCTAssertEqual(named["R2"], .rightTrigger)
        XCTAssertNil(named["Left Thumbstick X Axis"])

        // Eight numbered buttons already cover the triggers; the axes are left alone.
        let numbered = mapping.genericBindings(
            buttonNames: (1 ... 10).map { "Button \($0)" },
            directionNames: ["Hat Switch"],
            axisNames: ["Left Trigger", "Right Trigger"]
        )
        XCTAssertEqual(numbered["Button 7"], .leftTrigger)
        XCTAssertNil(numbered["Left Trigger"])
        XCTAssertEqual(numbered["Button 10"], .menu)
    }
}
