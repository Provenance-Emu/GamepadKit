// iCube's synthesized-element tests, from the same file as GamepadMappingTests/ICubeMappingTests.swift.
// Copyright 2026 iCube Project
// SPDX-License-Identifier: GPL-2.0-or-later
import GameController
import XCTest
import GamepadKit

/// The physical-profile adapter for pads the system exposes without an extended gamepad:
/// the shared C++ mapping through `PhysicalProfileBridge`, and the synthesized elements.
final class ICubeSynthesizedElementTests: XCTestCase {
  // MARK: Synthesized elements

  func testButtonUpdateFiresPressedThenValueHandlers() {
    let button = SynthesizedButtonInput()
    button.handlerOrder = .pressedThenValue // iCube's order; the package default is iFly's
    var events: [String] = []
    button.pressedChangedHandler = { _, value, pressed in events.append("pressed \(pressed) \(value)") }
    button.valueChangedHandler = { _, value, pressed in events.append("value \(pressed) \(value)") }

    button.update(value: 1, pressed: true)
    XCTAssertTrue(button.isPressed)
    XCTAssertEqual(button.value, 1)
    XCTAssertEqual(events, ["pressed true 1.0", "value true 1.0"])

    events.removeAll()
    button.update(value: 1, pressed: true)
    XCTAssertTrue(events.isEmpty, "no change, no callbacks")

    button.update(value: 0, pressed: false)
    XCTAssertFalse(button.isPressed)
    XCTAssertEqual(events, ["pressed false 0.0", "value false 0.0"])
  }

  func testDirectionPadUpdateSetsAxesAndDigitalDirections() {
    let pad = SynthesizedDirectionPad()
    var reported: (Float, Float)?
    pad.valueChangedHandler = { _, x, y in reported = (x, y) }

    pad.update(x: -1, y: 0.75)
    XCTAssertEqual(pad.xAxis.value, -1)
    XCTAssertEqual(pad.yAxis.value, 0.75)
    XCTAssertTrue(pad.left.isPressed)
    XCTAssertTrue(pad.up.isPressed)
    XCTAssertFalse(pad.right.isPressed)
    XCTAssertFalse(pad.down.isPressed)
    XCTAssertEqual(reported?.0, -1)
    XCTAssertEqual(reported?.1, 0.75)

    pad.update(x: 0.2, y: -0.2)
    XCTAssertFalse(pad.left.isPressed, "below the digital threshold")
    XCTAssertFalse(pad.down.isPressed)
  }

  func testOptionalButtonsAreReportedOnlyWhenThePadHasThem() {
    let gamepad = SynthesizedExtendedGamepad()
    XCTAssertNil(gamepad.buttonOptions)
    XCTAssertNil(gamepad.buttonHome)
    XCTAssertNil(gamepad.leftThumbstickButton)
    gamepad.hasOptions = true
    gamepad.hasHome = true
    XCTAssertNotNil(gamepad.buttonOptions)
    XCTAssertNotNil(gamepad.buttonHome)
  }

  func testGamepadElementsResolveByInputAndNotifyWholeGamepadObservers() {
    let gamepad = SynthesizedExtendedGamepad()
    var changed: [GCControllerElement] = []
    gamepad.valueChangedHandler = { _, element in changed.append(element) }

    XCTAssertTrue(gamepad.button(for: .buttonA) === gamepad.buttonA)
    XCTAssertTrue(gamepad.button(for: .menu) === gamepad.buttonMenu)
    XCTAssertTrue(gamepad.pad(for: .rightThumbstick) === gamepad.rightThumbstick)
    XCTAssertNil(gamepad.button(for: .dpad))
    XCTAssertNil(gamepad.pad(for: .rightStickUp))

    gamepad.button(for: .buttonA)!.update(value: 1, pressed: true)
    gamepad.notify(gamepad.buttonA)
    XCTAssertTrue(changed.first === gamepad.buttonA)
  }

  func testSynthesizedInputClassification() {
    XCTAssertTrue(GamepadInput.rightStickUp.isCButton)
    XCTAssertFalse(GamepadInput.rightThumbstick.isCButton)
    XCTAssertTrue(GamepadInput.dpad.isDirection)
    XCTAssertFalse(GamepadInput.buttonA.isDirection)
  }

  func testSynthesizedGamepadReportsStickClicksOnlyWhenThePadHasThem() {
    let gamepad = SynthesizedExtendedGamepad()
    XCTAssertNil(gamepad.leftThumbstickButton)
    XCTAssertNil(gamepad.rightThumbstickButton)
    gamepad.hasLeftThumbstickButton = true
    XCTAssertTrue(gamepad.leftThumbstickButton === gamepad.button(for: .leftThumbstickButton))
    XCTAssertNil(gamepad.rightThumbstickButton)
    gamepad.hasRightThumbstickButton = true
    XCTAssertTrue(gamepad.rightThumbstickButton === gamepad.button(for: .rightThumbstickButton))
    XCTAssertFalse(GamepadInput.leftThumbstickButton.isDirection)
  }
}
