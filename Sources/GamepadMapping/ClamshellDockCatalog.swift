import Foundation

/// When an app keeps its UI above a clamshell controller: one the phone docks into
/// upright, so the pad folds up over the bottom of the screen (8BitDo FlipPad and similar).
@frozen public enum ClamshellDockMode: String, CaseIterable, Sendable {
    /// Move the UI up when a pad from ``ClamshellDockCatalog`` is connected.
    case automatic
    /// Always move the UI up in portrait (a pad the catalog does not know).
    case always
    case off
}

/// Clamshell controllers recognised by name. Pure strings, so it is testable
/// without a controller.
@frozen public enum ClamshellDockCatalog {
    public struct Entry: Sendable, Equatable {
        /// Lowercased text the controller's name contains.
        public let nameContains: String
        /// Height of screen the folded-up pad hides, measured from the bottom edge.
        public let coverMillimetres: Double

        public init(nameContains: String, coverMillimetres: Double) {
            self.nameContains = nameContains
            self.coverMillimetres = coverMillimetres
        }
    }

    /// Used when the player turns the dock on by hand, or an entry has no better figure.
    public static let defaultCoverMillimetres: Double = 38

    /// 8BitDo FlipPad and GameSir Pocket Taco. The FlipPad height is from a real pad
    /// on an iPhone 16 Pro Max: 38 mm left 2 to 2.5 inches of the app under it, so
    /// 96 mm, well over half the screen. The Pocket Taco height is still an estimate,
    /// as is every name fragment; correct them when one is measured.
    public static let entries: [Entry] = [
        Entry(nameContains: "flippad", coverMillimetres: 96),
        Entry(nameContains: "flip pad", coverMillimetres: 96),
        Entry(nameContains: "pocket taco", coverMillimetres: 38),
        Entry(nameContains: "pockettaco", coverMillimetres: 38)
    ]

    public static func entry(forControllerNamed name: String?) -> Entry? {
        guard let name = name?.lowercased() else { return nil }
        return entries.first { name.contains($0.nameContains) }
    }

    /// iPhone screens are 153 points per inch within a few percent, whatever the model.
    public static let pointsPerMillimetre: Double = 153.0 / 25.4

    /// The bottom strip to keep clear, in points, or 0 for none.
    /// - Parameters:
    ///   - storedMillimetres: the player's own figure; 0 uses the catalog's.
    public static func coverPoints(
        mode: ClamshellDockMode,
        storedMillimetres: Double,
        controllerNames: [String?]
    ) -> Double {
        let matched = controllerNames.lazy.compactMap { entry(forControllerNamed: $0) }.first
        let active: Bool
        switch mode {
        case .off: active = false
        case .always: active = true
        case .automatic: active = matched != nil
        }
        guard active else { return 0 }
        let millimetres = storedMillimetres > 0
            ? storedMillimetres
            : (matched?.coverMillimetres ?? defaultCoverMillimetres)
        return (millimetres * pointsPerMillimetre).rounded()
    }
}
