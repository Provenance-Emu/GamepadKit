import Foundation

/// What is known about a controller when deciding whether to synthesize an extended
/// gamepad for it.
public struct WrapCandidate: Sendable, Equatable {
    public var family: PadFamily
    public var productCategory: String?
    public var hasExtendedGamepad: Bool
    public var hasMicroGamepad: Bool
    /// The app's own remote test (iCube's `isMenuRemote`), on top of the product category.
    public var isRemote: Bool
    public var bindings: [String: GamepadInput]

    public init(
        family: PadFamily,
        productCategory: String?,
        hasExtendedGamepad: Bool = false,
        hasMicroGamepad: Bool,
        isRemote: Bool = false,
        bindings: [String: GamepadInput]
    ) {
        self.family = family
        self.productCategory = productCategory
        self.hasExtendedGamepad = hasExtendedGamepad
        self.hasMicroGamepad = hasMicroGamepad
        self.isRemote = isRemote
        self.bindings = bindings
    }

    var looksLikeRemote: Bool {
        isRemote || (family == .generic && PhysicalProfileMapping.isRemoteCategory(productCategory))
    }
}

/// Which pads get a synthesized extended gamepad. Every policy requires no extended
/// gamepad, usable bindings (a direction input and a face button) and not a remote:
/// a Siri Remote has a direction pad and buttons too, and a wrapper would turn it
/// into a player.
public enum WrapPolicy: Sendable, Equatable {
    /// Any pad that passes the common test. iFly.
    case anyUsablePad
    /// As ``anyUsablePad``, but a generic pad that has a micro profile must also have
    /// a button no remote has (B or Y): a remote that reports an unknown product
    /// category then still stays a remote, at the cost of not wrapping a one-button
    /// pad that also reports a micro profile. Provenance.
    case usablePadNotRemoteLike
    /// A pad with no micro gamepad either, or a Switch Online pad whatever else it
    /// exposes. A generic pad that has a micro profile keeps the system's profiles.
    /// iCube (before generic-pad support).
    case switchOnlineOrProfileOnly

    public func shouldWrap(_ candidate: WrapCandidate) -> Bool {
        guard !candidate.hasExtendedGamepad, !candidate.looksLikeRemote,
              PhysicalProfileMapping.isUsable(bindings: candidate.bindings) else { return false }
        switch self {
        case .anyUsablePad:
            return true
        case .usablePadNotRemoteLike:
            guard candidate.family == .generic, candidate.hasMicroGamepad else { return true }
            return !Set(candidate.bindings.values).isDisjoint(with: [.buttonB, .buttonY])
        case .switchOnlineOrProfileOnly:
            return !candidate.hasMicroGamepad || candidate.family.isSwitchOnline
        }
    }
}
