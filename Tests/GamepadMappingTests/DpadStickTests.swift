import GamepadMapping
import XCTest

final class DpadStickTests: XCTestCase {
    func testAutomaticModeIsBothOnlyForAPadWithNoStick() {
        XCTAssertEqual(DpadMode.automatic(boundInputs: [.dpad, .buttonA]), .both)
        XCTAssertEqual(DpadMode.automatic(boundInputs: [.dpad, .leftThumbstick, .buttonA]), .dpad)
        XCTAssertEqual(DpadMode.automatic(boundInputs: [.leftThumbstick, .buttonA]), .dpad, "no D-pad to borrow")
    }

    func testModesCycleBothWays() {
        XCTAssertEqual(DpadMode.dpad.cycled(), .leftStick)
        XCTAssertEqual(DpadMode.leftStick.cycled(), .both)
        XCTAssertEqual(DpadMode.both.cycled(), .dpad)
        XCTAssertEqual(DpadMode.dpad.cycled(forward: false), .both)
        XCTAssertTrue(DpadMode.both.drivesDpad && DpadMode.both.drivesStick)
        XCTAssertFalse(DpadMode.leftStick.drivesDpad)
        XCTAssertFalse(DpadMode.dpad.drivesStick)
    }

    func testFullResponseIsImmediateAndDiagonalsStayOnTheUnitCircle() {
        var emulator = DpadStickEmulator()
        XCTAssertFalse(emulator.isActive)
        emulator.setDirection(x: 1, y: 0, at: 10)
        XCTAssertEqual(emulator.stick(at: 10).x, 1)
        XCTAssertFalse(emulator.isRamping(at: 10))

        emulator.setDirection(x: 1, y: 1, at: 11)
        let diagonal = emulator.stick(at: 11)
        XCTAssertEqual(diagonal.x, 0.7071, accuracy: 0.001)
        XCTAssertEqual(diagonal.y, 0.7071, accuracy: 0.001)

        emulator.setDirection(x: 0.3, y: -0.3, at: 12)
        XCTAssertFalse(emulator.isActive, "below the digital threshold")
        XCTAssertEqual(emulator.stick(at: 12).x, 0)
    }

    func testRampStartsLowAndReachesFullAfterItsDuration() {
        var emulator = DpadStickEmulator(response: .ramp(start: 0.4, duration: 0.2))
        emulator.setDirection(x: 0, y: -1, at: 5)
        XCTAssertEqual(emulator.stick(at: 5).y, -0.4, accuracy: 0.0001)
        XCTAssertEqual(emulator.stick(at: 5.1).y, -0.7, accuracy: 0.0001)
        XCTAssertTrue(emulator.isRamping(at: 5.1))
        XCTAssertEqual(emulator.stick(at: 5.2).y, -1, accuracy: 0.0001)
        XCTAssertEqual(emulator.stick(at: 9).y, -1, accuracy: 0.0001)
        XCTAssertFalse(emulator.isRamping(at: 5.2))
    }

    func testEachAxisRampsOnItsOwnAndAReversalStartsAgain() {
        var emulator = DpadStickEmulator(response: .ramp(start: 0.5, duration: 1))
        emulator.setDirection(x: 1, y: 0, at: 0)
        emulator.setDirection(x: 1, y: 1, at: 2) // x has long been full; y only now starts
        let stick = emulator.stick(at: 2)
        XCTAssertGreaterThan(stick.x, stick.y)
        XCTAssertTrue(emulator.isRamping(at: 2.5))

        emulator.setDirection(x: -1, y: 0, at: 3)
        XCTAssertEqual(emulator.stick(at: 3).x, -0.5, accuracy: 0.0001, "the new direction starts from the floor")
        emulator.setDirection(x: -1, y: 0, at: 3.5)
        XCTAssertEqual(emulator.stick(at: 3.5).x, -0.75, accuracy: 0.0001,
                       "a repeat of the same direction does not restart")
    }

    func testModifierScalesTheStick() {
        var emulator = DpadStickEmulator(response: .full, modifierScale: 0.5)
        emulator.setDirection(x: -1, y: 0, at: 0)
        XCTAssertEqual(emulator.stick(at: 0, modifierHeld: true).x, -0.5)
        XCTAssertEqual(emulator.stick(at: 0, modifierHeld: false).x, -1)
    }
}
