import GameController
import GamepadKit

/// A physical input profile made of settable elements, so a test can press buttons.
final class FakeProfile: GCPhysicalInputProfile, @unchecked Sendable {
    var fakeButtons: [String: SynthesizedButtonInput] = [:]
    var fakeDpads: [String: SynthesizedDirectionPad] = [:]
    var fakeAxes: [String: SynthesizedAxisInput] = [:]

    override var buttons: [String: GCControllerButtonInput] { fakeButtons }
    override var dpads: [String: GCControllerDirectionPad] { fakeDpads }
    override var axes: [String: GCControllerAxisInput] { fakeAxes }
    override var elements: [String: GCControllerElement] {
        var all: [String: GCControllerElement] = [:]
        fakeButtons.forEach { all[$0.key] = $0.value }
        fakeDpads.forEach { all[$0.key] = $0.value }
        fakeAxes.forEach { all[$0.key] = $0.value }
        return all
    }
}

/// A controller with no extended gamepad, as the system reports a Switch Online or
/// plain HID pad.
final class FakeController: GCController, @unchecked Sendable {
    let profile = FakeProfile()
    private let name: String?
    private let category: String
    private var index: GCControllerPlayerIndex = .indexUnset

    init(
        vendorName: String?,
        productCategory: String,
        buttons: [String] = [],
        dpads: [String] = [],
        axes: [String] = []
    ) {
        name = vendorName
        category = productCategory
        super.init()
        buttons.forEach { profile.fakeButtons[$0] = SynthesizedButtonInput() }
        dpads.forEach { profile.fakeDpads[$0] = SynthesizedDirectionPad() }
        axes.forEach { profile.fakeAxes[$0] = SynthesizedAxisInput() }
    }

    /// Apple's `_GCNintendoSuperFamicomControllerProfile`: nine elements, no Home, no ZL/ZR.
    static func snes() -> FakeController {
        FakeController(
            vendorName: "SNES Controller", productCategory: "Switch SNES Controller",
            buttons: ["Button A", "Button B", "Button X", "Button Y", "Left Shoulder", "Right Shoulder",
                      "Button Menu", "Button Options"],
            dpads: ["Direction Pad"]
        )
    }

    func press(_ name: String, _ pressed: Bool = true) {
        profile.fakeButtons[name]!.update(value: pressed ? 1 : 0, pressed: pressed)
    }

    func tap(_ name: String) {
        press(name, true)
        press(name, false)
    }

    override var extendedGamepad: GCExtendedGamepad? { nil }
    override var microGamepad: GCMicroGamepad? { nil }
    override var physicalInputProfile: GCPhysicalInputProfile { profile }
    override var vendorName: String? { name }
    override var productCategory: String { category }
    override var playerIndex: GCControllerPlayerIndex {
        get { index }
        set { index = newValue }
    }
}

/// Counts callbacks from `@Sendable` closures.
final class Counter: @unchecked Sendable {
    var count = 0
    var triggers: [PauseTrigger] = []
}
