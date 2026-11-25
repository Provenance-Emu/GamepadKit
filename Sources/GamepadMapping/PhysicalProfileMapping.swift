import Foundation

/// Maps the element names of a controller's physical input profile onto extended-gamepad
/// inputs. Pure strings, so it is unit-testable without a controller.
///
/// Order: the GameController framework's own element names first (on a family in the
/// table's ``MappingTable/labelFaceFamilies`` the four face names resolve as printed
/// labels instead), then the printed-label aliases of the pad family, then the common
/// aliases, then bare "Button <n>" names through the family's HID table. A generic pad
/// then takes what is left by position (``genericBindings(buttonNames:directionNames:axisNames:)``).
public struct PhysicalProfileMapping: Sendable, Equatable {
    public var table: MappingTable

    public init(table: MappingTable = .retroPad) {
        self.table = table
    }

    // MARK: Names

    /// Lowercases, turns `-`/`_` into spaces and collapses whitespace.
    public static func normalize(_ name: String) -> String {
        let spaced = name.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return spaced.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func bare(_ normalized: String) -> String {
        normalized.hasPrefix("button ") ? String(normalized.dropFirst("button ".count)) : normalized
    }

    /// The number in a bare "Button <n>" / "<n>" element name.
    public static func buttonIndex(_ name: String) -> Int? {
        Int(bare(normalize(name)))
    }

    /// The family the table resolves a controller as: the detected one when the table
    /// knows it, otherwise generic.
    public func family(vendorName: String?, productCategory: String?) -> PadFamily {
        let detected = PadFamily.detect(vendorName: vendorName, productCategory: productCategory)
        return table.families.contains(detected) ? detected : .generic
    }

    // MARK: Named elements

    /// The input an element should drive, or nil when its name says nothing.
    /// - Parameters:
    ///   - name: the key of `physicalInputProfile.elements`.
    ///   - pad: the family, which selects the face labels and the "Button <n>" table.
    public func input(forElementNamed name: String, pad: PadFamily = .generic) -> GamepadInput? {
        let normalized = Self.normalize(name)
        let bare = Self.bare(normalized)
        if table.labelFaceFamilies.contains(pad), MappingTable.standardFaceNames.contains(normalized),
           let face = table.faceAliases[pad]?[bare] {
            return face
        }
        if let standard = table.standardNames[normalized] { return standard }
        if let face = table.faceAliases[pad]?[bare] { return face }
        if let common = table.commonAliases[bare] { return common }
        if let index = Int(bare) { return table.hidButtons[pad]?[index] }
        return nil
    }

    /// Resolves every element name; later names never override an earlier binding of the
    /// same input, so the system's standard names win over aliases regardless of order.
    public func bindings(forElementNames names: [String], pad: PadFamily = .generic) -> [String: GamepadInput] {
        var result: [String: GamepadInput] = [:]
        var taken: Set<GamepadInput> = []
        for name in standardFirst(names) {
            guard let input = input(forElementNamed: name, pad: pad), !taken.contains(input) else { continue }
            result[name] = input
            taken.insert(input)
        }
        return result
    }

    /// The framework's standard names first, then the rest alphabetically.
    private func standardFirst(_ names: [String]) -> [String] {
        names.sorted { lhs, rhs in
            let lhsStandard = table.standardNames[Self.normalize(lhs)] != nil
            let rhsStandard = table.standardNames[Self.normalize(rhs)] != nil
            return lhsStandard != rhsStandard ? lhsStandard : lhs < rhs
        }
    }

    // MARK: Positional fallback

    /// Inputs handed, in this order, to buttons whose names say nothing ("Button 3").
    public static let fallbackButtonOrder: [GamepadInput] = [
        .buttonA, .buttonB, .buttonX, .buttonY, .leftShoulder, .rightShoulder,
        .leftTrigger, .rightTrigger, .options, .menu, .leftThumbstickButton, .rightThumbstickButton
    ]
    /// Inputs handed, in this order, to direction elements with unknown names.
    public static let fallbackDirectionOrder: [GamepadInput] = [.dpad, .leftThumbstick, .rightThumbstick]

    /// Bindings for a generic pad the system exposes without an extended gamepad (a
    /// plain USB/Bluetooth HID pad): names first, as ``bindings(forElementNames:pad:)``,
    /// then leftover elements by position so a pad whose elements are only numbered
    /// still works. The position order is a guess; the player corrects it in the app's
    /// remap screen.
    ///
    /// Leftover direction elements fill the unused direction inputs. Leftover buttons
    /// fill the unused button inputs when their name is only a number, or when the
    /// names alone gave no face button. Buttons that are one direction of a direction
    /// element ("Direction Pad Up") or a stick click are never taken.
    ///
    /// Last, an axis NAMED as a trigger ("Left Trigger", "L2", "ZL") takes that
    /// trigger if no button did: some pads report analog triggers as axes only.
    /// Axes go last so a pad that has both the digital trigger buttons and the axes
    /// keeps its positional button order. Axis names never take part in the names
    /// pass, so an axis cannot claim an input a button should have.
    /// - Parameters:
    ///   - buttonNames: the keys of `physicalInputProfile.buttons`.
    ///   - directionNames: the keys of `physicalInputProfile.dpads`.
    ///   - axisNames: the keys of `physicalInputProfile.axes`.
    public func genericBindings(
        buttonNames: [String],
        directionNames: [String],
        axisNames: [String] = []
    ) -> [String: GamepadInput] {
        // Names. A direction element takes only a direction input and a button only a
        // button input, so a button that happens to be called "Hat" cannot leave the
        // pad without its real D-pad.
        let directions = Set(directionNames)
        var result: [String: GamepadInput] = [:]
        var taken: Set<GamepadInput> = []
        for name in standardFirst(buttonNames + directionNames) where result[name] == nil {
            guard let input = input(forElementNamed: name), !taken.contains(input),
                  input.isDirection == directions.contains(name) else { continue }
            result[name] = input
            taken.insert(input)
        }

        var freeDirections = Self.fallbackDirectionOrder.filter { !taken.contains($0) }
        for name in directionNames.sorted(by: Self.naturalOrder) where result[name] == nil && !freeDirections.isEmpty {
            let input = freeDirections.removeFirst()
            result[name] = input
            taken.insert(input)
        }

        let directionPrefixes = directionNames.map { Self.normalize($0) + " " }
        let leftover = buttonNames.filter { name in
            guard result[name] == nil, !directions.contains(name) else { return false }
            let normalized = Self.normalize(name)
            return !directionPrefixes.contains { normalized.hasPrefix($0) } && !normalized.contains("thumbstick")
        }
        let hasFace = !taken.isDisjoint(with: GamepadInput.faceButtons)
        var freeButtons = Self.fallbackButtonOrder.filter { !taken.contains($0) }
        for name in leftover.sorted(by: Self.naturalOrder) where !freeButtons.isEmpty {
            guard !hasFace || Self.buttonIndex(name) != nil else { continue }
            let input = freeButtons.removeFirst()
            result[name] = input
            taken.insert(input)
        }

        for name in axisNames.sorted() where result[name] == nil {
            guard let input = input(forElementNamed: name), GamepadInput.triggers.contains(input),
                  !taken.contains(input) else { continue }
            result[name] = input
            taken.insert(input)
        }
        return result
    }

    /// Bare button numbers first, then other names ordered by prefix and trailing number.
    private static func naturalOrder(_ lhs: String, _ rhs: String) -> Bool {
        naturalKey(lhs) < naturalKey(rhs)
    }

    /// Sort key for ``naturalOrder``: bare "Button n" names first, then by prefix and
    /// trailing number, so "Generic Button 2" comes before "Generic Button 10".
    private struct NaturalKey: Comparable {
        var group: Int
        var prefix: String
        var index: Int
        var name: String

        static func < (lhs: NaturalKey, rhs: NaturalKey) -> Bool {
            (lhs.group, lhs.prefix, lhs.index, lhs.name) < (rhs.group, rhs.prefix, rhs.index, rhs.name)
        }
    }

    private static func naturalKey(_ name: String) -> NaturalKey {
        if let index = buttonIndex(name) { return NaturalKey(group: 0, prefix: "", index: index, name: name) }
        let normalized = normalize(name)
        let digits = normalized.reversed().prefix { $0.isASCII && $0.isNumber }
        if let index = Int(String(digits.reversed())) {
            return NaturalKey(group: 1, prefix: String(normalized.dropLast(digits.count)), index: index, name: name)
        }
        return NaturalKey(group: 1, prefix: normalized, index: -1, name: name)
    }

    /// Selects one name for a physical element before assigning positional slots.
    public func preferredName(amongAliases aliases: [String], pad: PadFamily = .generic) -> String? {
        func rank(_ name: String) -> Int {
            if table.standardNames[Self.normalize(name)] != nil { return 0 }
            return input(forElementNamed: name, pad: pad) == nil ? 2 : 1
        }

        return aliases.min { lhs, rhs in
            let left = rank(lhs)
            let right = rank(rhs)
            return left == right ? Self.naturalOrder(lhs, rhs) : left < right
        }
    }

    /// The bindings for a controller: a Switch Online pad resolves by its family's
    /// names; any other pad also takes leftover elements by position.
    /// - Parameters:
    ///   - elementNames: the keys of `physicalInputProfile.elements`.
    ///   - buttonNames: the keys of `physicalInputProfile.buttons`.
    ///   - directionNames: the keys of `physicalInputProfile.dpads`.
    ///   - axisNames: the keys of `physicalInputProfile.axes`.
    public func resolveBindings(
        pad: PadFamily,
        elementNames: [String],
        buttonNames: [String],
        directionNames: [String],
        axisNames: [String]
    ) -> [String: GamepadInput] {
        guard pad == .generic else { return bindings(forElementNames: elementNames, pad: pad) }
        return genericBindings(buttonNames: buttonNames, directionNames: directionNames, axisNames: axisNames)
    }

    // MARK: Usability

    /// Whether a profile exposes enough to be worth synthesizing: a direction input and a face button.
    public static func isUsable(bindings: [String: GamepadInput]) -> Bool {
        let inputs = Set(bindings.values)
        let hasDirection = !inputs.isDisjoint(with: [.dpad, .leftThumbstick])
        let hasButton = !inputs.isDisjoint(with: GamepadInput.faceButtons)
        return hasDirection && hasButton
    }

    /// Whether a product category names a remote (Siri Remote, Control Center remote,
    /// a TV's own remote) rather than a gamepad. A remote has a direction pad and
    /// buttons too, but it navigates menus and must stay a micro gamepad.
    public static func isRemoteCategory(_ productCategory: String?) -> Bool {
        productCategory?.lowercased().contains("remote") ?? false
    }

    /// Name for a pad the system reports without one, so its remaps and its row in
    /// controller lists are not shared with every other unnamed pad.
    public static func fallbackVendorName(productCategory: String) -> String {
        let category = productCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        return category.isEmpty ? "Gamepad" : "\(category) Gamepad"
    }
}
