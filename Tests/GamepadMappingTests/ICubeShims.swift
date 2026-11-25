import Foundation
import GamepadMapping

// iCube's names for the things its tests call, expressed through the package, so
// ICubeMappingTests stays a near-verbatim copy of iCube's own
// `DolphiniOSTests/PhysicalProfileMappingTests.swift`.

let iCubeMapping = PhysicalProfileMapping(table: .gameCube)

/// The MFi input names iCube's C++ core publishes (`ciface::iOS::PhysicalProfile::InputName`),
/// which are the raw values of iCube's `SynthesizedInput`.
let iCubeInputNames: [GamepadInput: String] = [
    .dpad: "D-Pad", .leftThumbstick: "L Stick", .rightThumbstick: "R Stick",
    .buttonA: "Button A", .buttonB: "Button B", .buttonX: "Button X", .buttonY: "Button Y",
    .leftShoulder: "L Shoulder", .rightShoulder: "R Shoulder",
    .leftTrigger: "L Trigger", .rightTrigger: "R Trigger",
    .menu: "Menu", .options: "Options", .home: "Home",
    .rightStickUp: "R Stick Y+", .rightStickDown: "R Stick Y-",
    .rightStickLeft: "R Stick X-", .rightStickRight: "R Stick X+",
    .leftThumbstickButton: "L Stick Button", .rightThumbstickButton: "R Stick Button"
]

typealias SynthesizedInput = GamepadInput

extension GamepadInput {
    /// iCube's `SynthesizedInput(rawValue:)`: from the MFi input name.
    init?(mfiName: String) {
        guard let match = iCubeInputNames.first(where: { $0.value == mfiName })?.key else { return nil }
        self = match
    }
}

/// `DOLPhysicalProfileBridge`: the C++ mapping as iCube's Swift sees it.
enum PhysicalProfileBridge {
    static func isN64Pad(withVendorName vendorName: String?, productCategory: String?) -> Bool {
        iCubeMapping.family(vendorName: vendorName, productCategory: productCategory) == .n64
    }

    static func isSnesPad(withVendorName vendorName: String?, productCategory: String?) -> Bool {
        iCubeMapping.family(vendorName: vendorName, productCategory: productCategory) == .snes
    }

    static func isSwitchOnlinePad(withVendorName vendorName: String?, productCategory: String?) -> Bool {
        iCubeMapping.family(vendorName: vendorName, productCategory: productCategory).isSwitchOnline
    }

    static func isRemoteProductCategory(_ productCategory: String?) -> Bool {
        PhysicalProfileMapping.isRemoteCategory(productCategory)
    }

    /// `PhysicalProfile::ResolveForPad`: a Switch Online pad and a remote by name alone,
    /// any other pad also by position. Empty when the profile is unusable.
    static func bindings(forVendorName vendorName: String?, productCategory: String?, buttonNames: [String],
                         directionNames: [String], axisNames: [String]) -> [String: String] {
        let family = iCubeMapping.family(vendorName: vendorName, productCategory: productCategory)
        let bindings: [String: GamepadInput]
        if family.isSwitchOnline || isRemoteProductCategory(productCategory) {
            bindings = iCubeMapping.bindings(
                forElementNames: buttonNames + directionNames + axisNames,
                pad: family == .n64 ? .n64 : .snes
            )
        } else {
            bindings = iCubeMapping.genericBindings(
                buttonNames: buttonNames, directionNames: directionNames, axisNames: axisNames
            )
        }
        guard PhysicalProfileMapping.isUsable(bindings: bindings) else { return [:] }
        return bindings.compactMapValues { iCubeInputNames[$0] }
    }

    /// `PhysicalProfile::TriggerValueFromAxis`.
    static func triggerValue(forAxisValue raw: Float, restsAtMinusOne: inout ObjCBool) -> Float {
        if TriggerAxis.readingIsBipolar(raw) { restsAtMinusOne = true }
        return TriggerAxis.state(forAxisValue: raw, restsAtMinusOne: restsAtMinusOne.boolValue).value
    }

    /// Element name → MFi input name; empty when the profile is unusable.
    static func bindings(forElementNames names: [String], isN64Pad: Bool) -> [String: String] {
        let bindings = iCubeMapping.bindings(forElementNames: names, pad: isN64Pad ? .n64 : .generic)
        guard PhysicalProfileMapping.isUsable(bindings: bindings) else { return [:] }
        return bindings.compactMapValues { iCubeInputNames[$0] }
    }
}

/// The static, controller-free parts of iCube's `PhysicalProfileController`.
enum ICubePhysicalProfileController {
    enum PauseTrigger: Equatable {
        case home, selectStartChord, standard, start
    }

    static func resolveBindings(elementNames: [String], vendorName: String?,
                                productCategory: String?) -> [String: SynthesizedInput] {
        let n64 = PhysicalProfileBridge.isN64Pad(withVendorName: vendorName, productCategory: productCategory)
        return PhysicalProfileBridge.bindings(forElementNames: elementNames, isN64Pad: n64)
            .compactMapValues { SynthesizedInput(mfiName: $0) }
    }

    static func resolveBindings(buttonNames: [String], directionNames: [String], axisNames: [String] = [],
                                vendorName: String?, productCategory: String?) -> [String: SynthesizedInput] {
        PhysicalProfileBridge.bindings(
            forVendorName: vendorName, productCategory: productCategory, buttonNames: buttonNames,
            directionNames: directionNames, axisNames: axisNames
        ).compactMapValues { SynthesizedInput(mfiName: $0) }
    }

    static func shouldWrap(hasExtendedGamepad: Bool, hasMicroGamepad: Bool, isMenuRemote: Bool,
                           isSwitchOnlinePad: Bool, bindings: [String: SynthesizedInput]) -> Bool {
        WrapPolicy.switchOnlineOrProfileOnly.shouldWrap(WrapCandidate(
            family: isSwitchOnlinePad ? .snes : .generic, productCategory: nil,
            hasExtendedGamepad: hasExtendedGamepad, hasMicroGamepad: hasMicroGamepad,
            isRemote: isMenuRemote, bindings: bindings
        ))
    }

    static func pauseTrigger(for bindings: [String: SynthesizedInput], isSnesPad: Bool) -> PauseTrigger {
        switch PausePolicy.homeSnesChordOrStart.trigger(forBindings: bindings, family: isSnesPad ? .snes : .generic) {
        case .home: return .home
        case .chord(GamepadMapping.PauseTrigger.selectStartChord): return .selectStartChord
        case .button(.menu): return .start
        case nil: return .standard
        default: fatalError("a trigger iCube has no name for")
        }
    }
}

/// iCube's `SelectStartChord`, on the package's tracker.
struct SelectStartChord {
    private var tracker = PauseTriggerTracker(trigger: .selectStart)

    var selectHeld: Bool { tracker.isHeld(.options) }
    var startHeld: Bool { tracker.isHeld(.menu) }

    mutating func update(_ input: SynthesizedInput, pressed: Bool) -> Bool {
        tracker.update(input, pressed: pressed) == .fired
    }
}
