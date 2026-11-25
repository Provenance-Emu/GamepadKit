import Foundation

/// Turns a raw trigger-axis reading into a trigger value. A trigger axis rests at 0
/// (range 0...1) on some pads and at -1 (range -1...1) on others; once it has reported
/// a negative value it is known to be the second kind.
public enum TriggerAxis {
    /// A trigger axis reporting below this is known to rest at -1.
    public static let bipolarThreshold: Float = -0.05
    /// A trigger driven from an axis counts as pressed above this value (0...1).
    public static let pressThreshold: Float = 0.25
    /// An axis already this far negative when first read is taken to rest at -1.
    public static let initialBipolarThreshold: Float = -0.5

    /// Whether a raw reading shows the axis rests at -1.
    public static func readingIsBipolar(_ raw: Float) -> Bool {
        raw < bipolarThreshold
    }

    /// Trigger value (0...1) and pressed state for a raw reading.
    /// - Parameter restsAtMinusOne: the axis has been seen below zero, so its range
    ///   is -1...1 and its midpoint is a half press.
    public static func state(forAxisValue raw: Float, restsAtMinusOne: Bool) -> (value: Float, pressed: Bool) {
        let value = max(0, min(1, restsAtMinusOne ? (raw + 1) / 2 : raw))
        return (value, value > pressThreshold)
    }
}
