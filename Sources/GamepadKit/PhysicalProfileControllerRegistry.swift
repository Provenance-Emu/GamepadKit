import GameController
import os

/// Owns the ``PhysicalProfileController`` wrappers, keyed by the real pad. A core that
/// holds its GCController weakly needs the wrapper kept alive for as long as the pad
/// is connected. Lock-protected: read from SwiftUI views and from GameController
/// handler queues alike.
public final class PhysicalProfileControllerRegistry: Sendable {
    /// One registry for the process; an app with a single controller manager needs no other.
    public static let shared = PhysicalProfileControllerRegistry()

    private let wrappers = OSAllocatedUnfairLock<[ObjectIdentifier: PhysicalProfileController]>(initialState: [:])

    public init() {}

    public func wrapper(for base: GCController) -> PhysicalProfileController? {
        let key = ObjectIdentifier(base)
        return wrappers.withLock { $0[key] }
    }

    public func register(_ wrapper: PhysicalProfileController) {
        let key = ObjectIdentifier(wrapper.base)
        wrappers.withLock { $0[key] = wrapper }
    }

    @discardableResult
    public func remove(base: GCController) -> PhysicalProfileController? {
        let key = ObjectIdentifier(base)
        return wrappers.withLock { $0.removeValue(forKey: key) }
    }

    /// `controllers` with every wrapped pad replaced by its wrapper, so code that reads
    /// `extendedGamepad` (menu navigation, player assignment) sees the synthesized one.
    public func substituting(_ controllers: [GCController]) -> [GCController] {
        let current = wrappers.withLock { $0 }
        guard !current.isEmpty else { return controllers }
        return controllers.map { current[ObjectIdentifier($0)] ?? $0 }
    }

    /// The real pad behind `controller` when it is a wrapper, otherwise `controller`.
    public static func base(of controller: GCController) -> GCController {
        (controller as? PhysicalProfileController)?.base ?? controller
    }
}
