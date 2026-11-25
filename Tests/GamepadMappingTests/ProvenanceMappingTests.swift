import XCTest
import GamepadMapping

final class ProvenanceMappingTests: XCTestCase {
    private static let mapping = PhysicalProfileMapping(table: .retroPad)
    private let policy = WrapPolicy.usablePadNotRemoteLike

    func testStandardSystemNamesResolve() {
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button A"), .buttonA)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Direction Pad"), .dpad)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Left Thumbstick"), .leftThumbstick)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button Options"), .options)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Right Trigger"), .rightTrigger)
        // Standard names are positional except a labelled pad's faces (SNES, N64, below).
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button B", pad: .generic), .buttonB)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button B", pad: .megaDrive), .buttonB)
    }

    func testPadDetection() {
        XCTAssertEqual(PadFamily.detect(vendorName: "N64 Controller", productCategory: "HID"), .n64)
        XCTAssertEqual(PadFamily.detect(vendorName: "SNES Controller", productCategory: "HID"), .snes)
        XCTAssertEqual(PadFamily.detect(vendorName: "MD/Gen Control Pad", productCategory: "HID"), .megaDrive)
        XCTAssertEqual(PadFamily.detect(vendorName: "DualSense Wireless Controller", productCategory: "DualSense"), .generic)
        XCTAssertEqual(PadFamily.detect(vendorName: nil, productCategory: nil), .generic)
    }

    func testN64LabelsFollowRetroArchSemantics() {
        // A → RetroPad B (extended A); B → RetroPad Y (extended X); Z → L2; ZR → Select; Start → Menu.
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "A", pad: .n64), .buttonA)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "B", pad: .n64), .buttonX)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Z", pad: .n64), .leftTrigger)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "ZR", pad: .n64), .options)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Start", pad: .n64), .menu)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Home", pad: .n64), .home)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "C-Up", pad: .n64), .rightStickUp)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "C Down", pad: .n64), .rightStickDown)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "c_left", pad: .n64), .rightStickLeft)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button C Right", pad: .n64), .rightStickRight)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "L", pad: .n64), .leftShoulder)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "R", pad: .n64), .rightShoulder)
    }

    func testSNESLabelsAreTheRetroPadLayout() {
        // SNES_Nintendo_Switch_Online.cfg: B → RetroPad B, A → A, Y → Y, X → X, ZL → L2, ZR → R2.
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "B", pad: .snes), .buttonA)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "A", pad: .snes), .buttonB)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Y", pad: .snes), .buttonX)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "X", pad: .snes), .buttonY)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "ZL", pad: .snes), .leftTrigger)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "ZR", pad: .snes), .rightTrigger)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "SELECT", pad: .snes), .options)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "START", pad: .snes), .menu)
        // The generic family uses the same face layout.
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "B"), .buttonA)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "A"), .buttonB)
    }

    func testMegaDriveLabels() {
        // MD_Gen_Control_Pad_Switch_Online.cfg: B → B, A → Y, Y → X, X → L, Z → R, C → A, Mode → Select.
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "B", pad: .megaDrive), .buttonA)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "A", pad: .megaDrive), .buttonX)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Y", pad: .megaDrive), .buttonY)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "X", pad: .megaDrive), .leftShoulder)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Z", pad: .megaDrive), .rightShoulder)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "C", pad: .megaDrive), .buttonB)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Mode", pad: .megaDrive), .options)
    }

    func testIndexedButtonsMatchAutoconfig() {
        // N64: b=1(A) a/y=0(B) start=9 select=10(ZR) l=4 r=5 l2=6(Z) r_x+=8 r_x-=3 r_y+=7 r_y-=2 menu=12
        let n64: [Int: GamepadInput] = [
            0: .buttonX, 1: .buttonA, 2: .rightStickUp, 3: .rightStickLeft, 4: .leftShoulder, 5: .rightShoulder,
            6: .leftTrigger, 7: .rightStickDown, 8: .rightStickRight, 9: .menu, 10: .options, 12: .home
        ]
        for (index, input) in n64 {
            XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button \(index)", pad: .n64), input, "N64 Button \(index)")
        }
        XCTAssertNil(ProvenanceMappingTests.mapping.input(forElementNamed: "Button 11", pad: .n64))
        // SNES: b=0 a=1 y=2 x=3 l=4 r=5 l2=6(ZL) select=8 start=9 r2=15(ZR)
        let snes: [Int: GamepadInput] = [
            0: .buttonA, 1: .buttonB, 2: .buttonX, 3: .buttonY, 4: .leftShoulder, 5: .rightShoulder,
            6: .leftTrigger, 8: .options, 9: .menu, 15: .rightTrigger
        ]
        for (index, input) in snes {
            XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button \(index)", pad: .snes), input, "SNES Button \(index)")
        }
        XCTAssertNil(ProvenanceMappingTests.mapping.input(forElementNamed: "Button 7", pad: .snes))
        // MD: b=0 y=1(A) x=2(Y) r=4(Z) a=5(C) l=6(X) select=7(Mode) start=9 menu=12(Home)
        let md: [Int: GamepadInput] = [
            0: .buttonA, 1: .buttonX, 2: .buttonY, 4: .rightShoulder, 5: .buttonB, 6: .leftShoulder, 7: .options, 9: .menu, 12: .home
        ]
        for (index, input) in md {
            XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button \(index)", pad: .megaDrive), input, "MD Button \(index)")
        }
        XCTAssertNil(ProvenanceMappingTests.mapping.input(forElementNamed: "Button 9", pad: .generic), "by name alone, indexed names need a known pad family")
    }

    func testStandardNamesWinOverAliasesForTheSameInput() {
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Start", "Button Menu", "B", "Button A", "Direction Pad"])
        XCTAssertEqual(bindings["Button Menu"], .menu)
        XCTAssertNil(bindings["Start"], "second name for an already-bound input is dropped")
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertNil(bindings["B"])
    }

    func testUsabilityNeedsDirectionAndFaceButton() {
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: ["Direction Pad": .dpad, "Button A": .buttonA]))
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: ["Left Thumbstick": .leftThumbstick, "B": .buttonX]))
        XCTAssertFalse(PhysicalProfileMapping.isUsable(bindings: ["Button A": .buttonA, "Button Menu": .menu]))
        XCTAssertFalse(PhysicalProfileMapping.isUsable(bindings: ["Direction Pad": .dpad]))
        XCTAssertFalse(PhysicalProfileMapping.isUsable(bindings: [:]))
    }

    func testUnknownNamesAreIgnored() {
        XCTAssertNil(ProvenanceMappingTests.mapping.input(forElementNamed: "Capture"))
        XCTAssertNil(ProvenanceMappingTests.mapping.input(forElementNamed: "Touchpad"))
    }

    // MARK: Switch Online SNES pad (VID 0x057E, PID 0x2017)

    /// The nine elements Apple's `_GCNintendoSuperFamicomControllerProfile` describes
    /// (GameController, iOS 26.6 and tvOS 27.2): no Home, no ZL/ZR.
    private let appleSNESElementNames = [
        "Button A", "Button B", "Button X", "Button Y", "Left Shoulder", "Right Shoulder",
        "Button Menu", "Button Options", "Direction Pad"
    ]

    func testSNESPadFromAppleProfileBindsEveryButtonOnce() {
        XCTAssertEqual(PadFamily.detect(vendorName: "SNES Controller", productCategory: "Switch SNES Controller"), .snes)
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        XCTAssertEqual(bindings, [
            "Button A": .buttonB, "Button B": .buttonA, "Button X": .buttonY, "Button Y": .buttonX,
            "Left Shoulder": .leftShoulder, "Right Shoulder": .rightShoulder,
            "Button Menu": .menu, "Button Options": .options, "Direction Pad": .dpad
        ])
        XCTAssertEqual(Set(bindings.values).count, bindings.count, "no two elements drive the same input")
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: bindings))
    }

    /// Apple names the SNES pad's faces by printed label, so "Button A" is the A button
    /// (right) and must drive RetroPad A, as the label alias and the RetroArch HID index
    /// do. Reading it positionally swapped A/B and X/Y in every core.
    func testSNESAppleFaceNamesAgreeWithLabelsAndHIDIndices() {
        let faces: [(apple: String, label: String, hid: String, expected: GamepadInput)] = [
            ("Button B", "B", "Button 0", .buttonA),
            ("Button A", "A", "Button 1", .buttonB),
            ("Button Y", "Y", "Button 2", .buttonX),
            ("Button X", "X", "Button 3", .buttonY)
        ]
        for face in faces {
            for name in [face.apple, face.label, face.hid] {
                XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: name, pad: .snes), face.expected, "SNES \(name)")
            }
        }
        XCTAssertTrue(ProvenanceMappingTests.mapping.table.labelFaceFamilies.contains(.snes))
        XCTAssertFalse(ProvenanceMappingTests.mapping.table.labelFaceFamilies.contains(.generic))
        XCTAssertTrue(ProvenanceMappingTests.mapping.table.labelFaceFamilies.contains(.n64))
        XCTAssertFalse(ProvenanceMappingTests.mapping.table.labelFaceFamilies.contains(.megaDrive))
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button A", pad: .generic), .buttonA)
    }

    func testSNESPadPausesOnSelectPlusStartNeverStartAlone() throws {
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        let trigger = try XCTUnwrap(PausePolicy.homeOrSelectStart.trigger(forBindings: bindings))
        XCTAssertEqual(trigger, .chord([.options, .menu]))
        XCTAssertFalse(trigger.isSatisfied(by: [.menu]), "Start alone is a game button")
        XCTAssertFalse(trigger.isSatisfied(by: [.options]), "Select alone is a game button")
        XCTAssertFalse(trigger.isSatisfied(by: [.menu, .buttonA]))
        XCTAssertTrue(trigger.isSatisfied(by: [.options, .menu]))
        XCTAssertTrue(trigger.isSatisfied(by: [.options, .menu, .dpad]))
        XCTAssertEqual(trigger.inputs, [.options, .menu])
    }

    /// Apple's "Button B" on the Switch Online N64 pad is the button marked B. Mupen (native and
    /// thin) reads N64 B from extended X, so it must land there; read positionally it drove
    /// extended B (C-Down) and N64 B did nothing until the tester remapped X to B.
    func testN64AppleFaceNamesAgreeWithLabelsAndHIDIndices() {
        let faces: [(apple: String, label: String, hid: String, expected: GamepadInput)] = [
            ("Button A", "A", "Button 1", .buttonA),
            ("Button B", "B", "Button 0", .buttonX)
        ]
        for face in faces {
            for name in [face.apple, face.label, face.hid] {
                XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: name, pad: .n64), face.expected, "N64 \(name)")
            }
        }
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Button A", "Button B", "Direction Pad", "Button Menu", "Button Home"], pad: .n64)
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertEqual(bindings["Button B"], .buttonX)
    }

    func testPadsWithHomePauseOnHome() throws {
        let n64 = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Button A", "Direction Pad", "Button Menu", "Button Options", "Button Home"], pad: .n64)
        let trigger = try XCTUnwrap(PausePolicy.homeOrSelectStart.trigger(forBindings: n64))
        XCTAssertEqual(trigger, .home)
        XCTAssertTrue(trigger.isSatisfied(by: [.home]))
        XCTAssertFalse(trigger.isSatisfied(by: [.menu, .options]), "with Home available, Select + Start stays a game chord")
        let megaDrive = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Button 0", "Direction Pad", "Button 9", "Button 12"], pad: .megaDrive)
        XCTAssertEqual(PausePolicy.homeOrSelectStart.trigger(forBindings: megaDrive), .home)
    }

    func testNoPauseTriggerWithoutHomeOrSelectStart() {
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Button A", "Direction Pad", "Button Menu"])
        XCTAssertNil(PausePolicy.homeOrSelectStart.trigger(forBindings: bindings))
        XCTAssertFalse(PauseTrigger.chord([]).isSatisfied(by: [.menu]))
    }

    func testOnlySwitchOnlinePadsAreFlagged() {
        XCTAssertTrue(PadFamily.snes.isSwitchOnline)
        XCTAssertTrue(PadFamily.n64.isSwitchOnline)
        XCTAssertTrue(PadFamily.megaDrive.isSwitchOnline)
        XCTAssertFalse(PadFamily.generic.isSwitchOnline)
    }

    // MARK: Stick clicks

    func testStickClicksResolveByStandardNameAndAlias() {
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Left Thumbstick Button"), .leftThumbstickButton)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Right Thumbstick Button"), .rightThumbstickButton)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "L3"), .leftThumbstickButton)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button R3"), .rightThumbstickButton)
        XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Left Thumbstick"), .leftThumbstick, "the stick itself is not its click")
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: ["Left Thumbstick", "Left Thumbstick Button", "L3", "Button A"])
        XCTAssertEqual(bindings["Left Thumbstick"], .leftThumbstick)
        XCTAssertEqual(bindings["Left Thumbstick Button"], .leftThumbstickButton)
        XCTAssertNil(bindings["L3"], "the standard name keeps the input")
    }

    // MARK: Generic HID pads

    func testNumberedButtonsAndAnUnnamedDirectionFillInputsInOrder() {
        let buttons = (1 ... 13).map { "Button \($0)" }
        let bindings = ProvenanceMappingTests.mapping.genericBindings(buttonNames: buttons, directionNames: ["Hat Switch"])
        XCTAssertEqual(bindings, [
            "Hat Switch": .dpad,
            "Button 1": .buttonA, "Button 2": .buttonB, "Button 3": .buttonX, "Button 4": .buttonY,
            "Button 5": .leftShoulder, "Button 6": .rightShoulder, "Button 7": .leftTrigger, "Button 8": .rightTrigger,
            "Button 9": .options, "Button 10": .menu,
            "Button 11": .leftThumbstickButton, "Button 12": .rightThumbstickButton
        ])
        XCTAssertNil(bindings["Button 13"], "nothing is left to hand out")
        XCTAssertTrue(PhysicalProfileMapping.isUsable(bindings: bindings))
        XCTAssertEqual(PausePolicy.homeOrSelectStart.trigger(forBindings: bindings), .chord([.options, .menu]))
    }

    func testNumberedButtonsOrderByNumberNotByText() {
        // "Button 10" sorts before "Button 2" as text; zero-based names work the same way.
        let bindings = ProvenanceMappingTests.mapping.genericBindings(buttonNames: ["Button 10", "Button 2", "Button 0", "Button 1"], directionNames: ["Direction Pad"])
        XCTAssertEqual(bindings["Button 0"], .buttonA)
        XCTAssertEqual(bindings["Button 1"], .buttonB)
        XCTAssertEqual(bindings["Button 2"], .buttonX)
        XCTAssertEqual(bindings["Button 10"], .buttonY)
    }

    func testUnnamedDirectionsFillDpadThenSticks() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(buttonNames: ["Button 1"], directionNames: ["Pad C", "Pad A", "Pad B", "Pad D"])
        XCTAssertEqual(bindings["Pad A"], .dpad)
        XCTAssertEqual(bindings["Pad B"], .leftThumbstick)
        XCTAssertEqual(bindings["Pad C"], .rightThumbstick)
        XCTAssertNil(bindings["Pad D"])
        // A named direction keeps its input; the unnamed one takes the first free.
        let mixed = ProvenanceMappingTests.mapping.genericBindings(buttonNames: ["Button 1"], directionNames: ["Direction Pad", "Pad A"])
        XCTAssertEqual(mixed["Direction Pad"], .dpad)
        XCTAssertEqual(mixed["Pad A"], .leftThumbstick)
    }

    func testNamedElementsKeepTheirInputAndDirectionHalvesAreNotButtons() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: ["Button A", "Button B", "Button Menu", "Direction Pad Up", "Direction Pad Left",
                          "Left Thumbstick Button", "Button Share"],
            directionNames: ["Direction Pad", "Left Thumbstick"])
        XCTAssertEqual(bindings["Button A"], .buttonA)
        XCTAssertEqual(bindings["Direction Pad"], .dpad)
        XCTAssertEqual(bindings["Left Thumbstick"], .leftThumbstick)
        XCTAssertNil(bindings["Direction Pad Up"])
        XCTAssertNil(bindings["Direction Pad Left"])
        XCTAssertEqual(bindings["Left Thumbstick Button"], .leftThumbstickButton)
        XCTAssertNil(bindings["Button Share"], "a named extra is left alone once the names gave a face button")
    }

    func testDirectionHalvesAreNotButtonsEvenWhenNoFaceButtonIsNamed() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: ["Hat Switch Up", "Hat Switch Down", "Left Thumbstick Left", "Fire"],
            directionNames: ["Hat Switch", "Left Thumbstick"])
        XCTAssertEqual(bindings, ["Hat Switch": .dpad, "Left Thumbstick": .leftThumbstick, "Fire": .buttonA])
    }

    func testOddlyNamedButtonsAreTakenWhenNamesGiveNoFaceButton() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(buttonNames: ["Fire", "Jump"], directionNames: ["Direction Pad"])
        XCTAssertEqual(bindings, ["Direction Pad": .dpad, "Fire": .buttonA, "Jump": .buttonB])
    }

    func testNumberedButtonsFillAroundNamedOnes() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: ["Button A", "Button B", "Left Shoulder", "Button 5", "Button 6"], directionNames: ["Direction Pad"])
        XCTAssertEqual(bindings["Button 5"], .buttonX)
        XCTAssertEqual(bindings["Button 6"], .buttonY)
        XCTAssertEqual(bindings["Left Shoulder"], .leftShoulder)
    }

    // MARK: Trigger axes

    func testATriggerAxisTakesTheTriggerOnlyWhenNoButtonDid() {
        let named = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: ["Button A", "Button B"], directionNames: ["Direction Pad"],
            axisNames: ["Left Trigger", "R2", "Left Thumbstick X Axis"])
        XCTAssertEqual(named["Left Trigger"], .leftTrigger)
        XCTAssertEqual(named["R2"], .rightTrigger)
        XCTAssertNil(named["Left Thumbstick X Axis"])

        // Numbered buttons already cover the triggers; the axes are left alone.
        let numbered = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: (1 ... 10).map { "Button \($0)" }, directionNames: ["Hat Switch"],
            axisNames: ["Left Trigger", "Right Trigger"])
        XCTAssertEqual(numbered["Button 7"], .leftTrigger)
        XCTAssertNil(numbered["Left Trigger"])
        XCTAssertNil(numbered["Right Trigger"])
        XCTAssertEqual(numbered["Button 10"], .menu)
    }

    func testAnAxisNeverTakesAnInputThatIsNotATrigger() {
        let bindings = ProvenanceMappingTests.mapping.genericBindings(
            buttonNames: ["Button A"], directionNames: ["Direction Pad"], axisNames: ["Start", "Button B", "L"])
        XCTAssertEqual(bindings, ["Button A": .buttonA, "Direction Pad": .dpad])
    }

    func testATriggerAxisRestingAtZeroReadsAsItsValue() {
        XCTAssertFalse(TriggerAxis.readingIsBipolar(0))
        XCTAssertFalse(TriggerAxis.readingIsBipolar(0.6))
        let rest = TriggerAxis.state(forAxisValue: 0, restsAtMinusOne: false)
        XCTAssertEqual(rest.value, 0)
        XCTAssertFalse(rest.pressed)
        let light = TriggerAxis.state(forAxisValue: 0.2, restsAtMinusOne: false)
        XCTAssertEqual(light.value, 0.2, accuracy: 0.0001)
        XCTAssertFalse(light.pressed)
        let full = TriggerAxis.state(forAxisValue: 1, restsAtMinusOne: false)
        XCTAssertEqual(full.value, 1)
        XCTAssertTrue(full.pressed)
        XCTAssertEqual(TriggerAxis.state(forAxisValue: 1.4, restsAtMinusOne: false).value, 1, "clamped")
    }

    func testATriggerAxisRestingAtMinusOneIsRescaled() {
        XCTAssertTrue(TriggerAxis.readingIsBipolar(-1))
        XCTAssertTrue(TriggerAxis.readingIsBipolar(-0.1))
        XCTAssertFalse(TriggerAxis.readingIsBipolar(-0.01), "noise around zero is not a resting position")
        let rest = TriggerAxis.state(forAxisValue: -1, restsAtMinusOne: true)
        XCTAssertEqual(rest.value, 0)
        XCTAssertFalse(rest.pressed)
        let half = TriggerAxis.state(forAxisValue: 0, restsAtMinusOne: true)
        XCTAssertEqual(half.value, 0.5, accuracy: 0.0001)
        XCTAssertTrue(half.pressed)
        let full = TriggerAxis.state(forAxisValue: 1, restsAtMinusOne: true)
        XCTAssertEqual(full.value, 1)
        XCTAssertTrue(full.pressed)
    }

    // MARK: Which pads to wrap

    /// Element names a Siri Remote exposes that resolve to inputs.
    private let remoteBindings: [String: GamepadInput] = ["Direction Pad": .dpad, "Button A": .buttonA, "Button X": .buttonX, "Button Menu": .menu]
    private let hidBindings = ProvenanceMappingTests.mapping.genericBindings(buttonNames: (1 ... 10).map { "Button \($0)" }, directionNames: ["Hat Switch"])

    func testRemotesAreNeverSynthesized() {
        for category in ["Siri Remote", "Siri Remote (2nd Generation)", "Coalesced Remote", "Control Center Remote", "Universal Electronics Remote"] {
            XCTAssertTrue(PhysicalProfileMapping.isRemoteCategory(category), category)
            XCTAssertFalse(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: category, hasMicroGamepad: true, bindings: remoteBindings)), category)
            XCTAssertFalse(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: category, hasMicroGamepad: false, bindings: hidBindings)), category)
        }
        XCTAssertFalse(PhysicalProfileMapping.isRemoteCategory("HID"))
        XCTAssertFalse(PhysicalProfileMapping.isRemoteCategory(nil))
        // A remote under a category that does not say so still has only A and X.
        XCTAssertFalse(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: "MFi", hasMicroGamepad: true, bindings: remoteBindings)))
    }

    func testGenericPadsAreSynthesizedWithOrWithoutAMicroProfile() {
        XCTAssertTrue(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: "HID", hasMicroGamepad: false, bindings: hidBindings)))
        XCTAssertTrue(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: "HID", hasMicroGamepad: true, bindings: hidBindings)))
        // Without a micro profile the old rule holds: a direction and one face button are enough.
        XCTAssertTrue(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: "HID", hasMicroGamepad: false, bindings: ["Direction Pad": .dpad, "Button A": .buttonA])))
        XCTAssertFalse(policy.shouldWrap(WrapCandidate(family: .generic, productCategory: "HID", hasMicroGamepad: false, bindings: ["Button A": .buttonA])))
    }

    func testSwitchOnlinePadsAreSynthesizedWhateverTheirCategorySays() {
        let bindings = ProvenanceMappingTests.mapping.bindings(forElementNames: appleSNESElementNames, pad: .snes)
        XCTAssertTrue(policy.shouldWrap(WrapCandidate(family: .snes, productCategory: "Switch SNES Controller", hasMicroGamepad: true, bindings: bindings)))
        XCTAssertTrue(policy.shouldWrap(WrapCandidate(family: .n64, productCategory: "Remote", hasMicroGamepad: true, bindings: ["Direction Pad": .dpad, "Button A": .buttonA])))
    }

    func testUnnamedPadsGetANameFromTheirCategory() {
        XCTAssertEqual(PhysicalProfileMapping.fallbackVendorName(productCategory: "HID"), "HID Gamepad")
        XCTAssertEqual(PhysicalProfileMapping.fallbackVendorName(productCategory: "  "), "Gamepad")
    }

    /// The tester's RetroArch autoconfig for this pad agrees with the SNES HID index table.
    func testSNESIndexTableMatchesTesterAutoconfig() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "SNES_Nintendo_Switch_Online", withExtension: "cfg", subdirectory: "Fixtures"))
        let config = try String(contentsOf: url, encoding: .utf8)
        var values: [String: String] = [:]
        for line in config.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            values[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        XCTAssertEqual(values["input_vendor_id"], "1406")
        XCTAssertEqual(values["input_product_id"], "8215")
        // RetroPad button → extended-gamepad input the cores read.
        let retroPad: [String: GamepadInput] = [
            "b": .buttonA, "a": .buttonB, "y": .buttonX, "x": .buttonY, "l": .leftShoulder, "r": .rightShoulder,
            "l2": .leftTrigger, "r2": .rightTrigger, "select": .options, "start": .menu
        ]
        for (button, input) in retroPad {
            let index = try XCTUnwrap(values["input_\(button)_btn"].flatMap(Int.init), "input_\(button)_btn")
            XCTAssertEqual(ProvenanceMappingTests.mapping.input(forElementNamed: "Button \(index)", pad: .snes), input, button)
        }
    }
}
