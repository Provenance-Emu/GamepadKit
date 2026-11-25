import Foundation

/// The pad family a physical input profile belongs to. Decides what printed labels and
/// bare "Button <n>" names mean: the N64 pad's A/B are its two face buttons, while the
/// SNES pad's B/A/Y/X are the RetroPad layout.
public enum PadFamily: String, CaseIterable, Sendable {
    case generic
    /// Nintendo Switch Online N64 controller (vendor name "N64 Controller").
    case n64
    /// Nintendo Switch Online SNES controller (vendor name "SNES Controller",
    /// product category "Switch SNES Controller", USB/BT 057E:2017).
    case snes
    /// Nintendo Switch Online Mega Drive / Genesis control pad.
    case megaDrive

    /// Detects the family from what the system reports for the controller.
    public static func detect(vendorName: String?, productCategory: String?) -> PadFamily {
        let haystack = ((vendorName ?? "") + " " + (productCategory ?? "")).lowercased()
        if haystack.contains("n64") { return .n64 }
        if haystack.contains("snes") || haystack.contains("super nintendo") || haystack.contains("super famicom") {
            return .snes
        }
        let megaDriveNames = ["md/gen", "mega drive", "megadrive", "genesis"]
        if megaDriveNames.contains(where: { haystack.contains($0) }) { return .megaDrive }
        return .generic
    }

    /// The Switch Online pads, which the system exposes without an extended gamepad.
    public var isSwitchOnline: Bool { self != .generic }
}
