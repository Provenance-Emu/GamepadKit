import GamepadMapping
import XCTest

/// The pieces the three apps' own tests do not reach.
final class PolicyTests: XCTestCase {
    func testATableTreatsAFamilyItDoesNotKnowAsGeneric() {
        let gameCube = PhysicalProfileMapping(table: .gameCube)
        XCTAssertEqual(gameCube.family(vendorName: "MD/Gen Control Pad", productCategory: "HID"), .generic)
        XCTAssertEqual(gameCube.family(vendorName: "N64 Controller", productCategory: "HID"), .n64)
        let retroPad = PhysicalProfileMapping(table: .retroPad)
        XCTAssertEqual(retroPad.family(vendorName: "MD/Gen Control Pad", productCategory: "HID"), .megaDrive)
    }

    func testTheTwoRetroPadTablesDifferOnlyInHowTheyReadSystemFaceNames() {
        var relaxed = MappingTable.retroPad
        relaxed.labelFaceFamilies = []
        XCTAssertEqual(relaxed, .retroPadSystemFaces)
        let labels = PhysicalProfileMapping(table: .retroPad)
        let positions = PhysicalProfileMapping(table: .retroPadSystemFaces)
        XCTAssertEqual(labels.input(forElementNamed: "Button A", pad: .snes), .buttonB)
        XCTAssertEqual(positions.input(forElementNamed: "Button A", pad: .snes), .buttonA)
        XCTAssertEqual(labels.input(forElementNamed: "Button A", pad: .megaDrive), .buttonA)
    }

    func testOptionalElementExposure() {
        let bound: Set<GamepadInput> = [.options, .menu]
        XCTAssertTrue(OptionalElementExposure.always.isExposed(.home, boundInputs: bound, pauseTrigger: nil))
        XCTAssertFalse(OptionalElementExposure.whenBound.isExposed(.home, boundInputs: bound, pauseTrigger: nil))
        XCTAssertTrue(OptionalElementExposure.whenBound
            .isExposed(.options, boundInputs: bound, pauseTrigger: .selectStart))
        XCTAssertFalse(OptionalElementExposure.whenBoundAndNotPauseTrigger
            .isExposed(.options, boundInputs: bound, pauseTrigger: .selectStart))
        XCTAssertTrue(OptionalElementExposure.whenBoundAndNotPauseTrigger
            .isExposed(.options, boundInputs: bound, pauseTrigger: .home))
    }

    func testASingleButtonTriggerFiresOncePerPressAndIsNeverHeldBack() {
        var tracker = PauseTriggerTracker(trigger: .button(.menu))
        XCTAssertEqual(tracker.update(.buttonA, pressed: true), .forward)
        XCTAssertEqual(tracker.update(.menu, pressed: true), .fired)
        XCTAssertEqual(tracker.update(.menu, pressed: true), .latched, "a repeated value while held")
        XCTAssertEqual(tracker.update(.menu, pressed: false), .latched)
        XCTAssertEqual(tracker.update(.menu, pressed: true), .fired)
        XCTAssertFalse(PauseTrigger.button(.menu).canHoldBackInputs)
        XCTAssertTrue(PauseTrigger.selectStart.canHoldBackInputs)
    }

    func testLoneTap() {
        var tap = LoneTapTracker(input: .options)
        XCTAssertFalse(tap.update(.options, pressed: true, wasHeld: false, held: [.options]))
        XCTAssertTrue(tap.update(.options, pressed: false, wasHeld: true, held: []))
        XCTAssertFalse(tap.update(.options, pressed: true, wasHeld: false, held: [.buttonA, .options]), "not alone")
        XCTAssertFalse(tap.update(.options, pressed: false, wasHeld: true, held: [.buttonA]))
        XCTAssertFalse(tap.update(.options, pressed: true, wasHeld: false, held: [.options]))
        tap.cancel()
        XCTAssertFalse(tap.update(.options, pressed: false, wasHeld: true, held: []))
    }
}
