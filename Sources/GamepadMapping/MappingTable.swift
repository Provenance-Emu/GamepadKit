import Foundation

/// The name tables a ``PhysicalProfileMapping`` resolves element names through. One
/// table per target convention: what "A" or "Z" should drive depends on what the
/// emulated console expects, so the apps do not share a single table.
///
/// All keys are normalized names (``PhysicalProfileMapping/normalize(_:)``); alias and
/// face keys have a leading "button " dropped.
public struct MappingTable: Sendable, Equatable {
    /// Element names the GameController framework uses for standard inputs
    /// (`GCInputButtonA` is "Button A", and so on).
    public var standardNames: [String: GamepadInput]
    /// Labels common to every family: shoulders, triggers, system buttons, directions.
    public var commonAliases: [String: GamepadInput]
    /// Printed face labels per family.
    public var faceAliases: [PadFamily: [String: GamepadInput]]
    /// Bare "Button <n>" indices per family (RetroArch HID autoconfig).
    public var hidButtons: [PadFamily: [Int: GamepadInput]]
    /// Families whose system face names ("Button A" …) are the printed labels rather
    /// than positions, so they resolve through ``faceAliases`` first.
    public var labelFaceFamilies: Set<PadFamily>
    /// Families this table knows. A pad detected as any other family is treated as generic.
    public var families: Set<PadFamily>

    public init(
        standardNames: [String: GamepadInput] = MappingTable.frameworkNames,
        commonAliases: [String: GamepadInput],
        faceAliases: [PadFamily: [String: GamepadInput]],
        hidButtons: [PadFamily: [Int: GamepadInput]],
        labelFaceFamilies: Set<PadFamily> = [],
        families: Set<PadFamily> = Set(PadFamily.allCases)
    ) {
        self.standardNames = standardNames
        self.commonAliases = commonAliases
        self.faceAliases = faceAliases
        self.hidButtons = hidButtons
        self.labelFaceFamilies = labelFaceFamilies
        self.families = families
    }

    /// The system's face element names.
    public static let standardFaceNames: Set<String> = ["button a", "button b", "button x", "button y"]

    /// The GameController framework's own element names. Shared by every table.
    public static let frameworkNames: [String: GamepadInput] = [
        "button a": .buttonA, "button b": .buttonB, "button x": .buttonX, "button y": .buttonY,
        "direction pad": .dpad, "left thumbstick": .leftThumbstick, "right thumbstick": .rightThumbstick,
        "left shoulder": .leftShoulder, "right shoulder": .rightShoulder,
        "left trigger": .leftTrigger, "right trigger": .rightTrigger,
        "left thumbstick button": .leftThumbstickButton, "right thumbstick button": .rightThumbstickButton,
        "button menu": .menu, "button options": .options, "button home": .home
    ]

    private static let stickClickAliases: [String: GamepadInput] = [
        "l3": .leftThumbstickButton, "left stick button": .leftThumbstickButton,
        "left stick click": .leftThumbstickButton, "thumbl": .leftThumbstickButton,
        "r3": .rightThumbstickButton, "right stick button": .rightThumbstickButton,
        "right stick click": .rightThumbstickButton, "thumbr": .rightThumbstickButton
    ]

    private static let directionAliases: [String: GamepadInput] = [
        "dpad": .dpad, "d pad": .dpad, "hat": .dpad,
        "left stick": .leftThumbstick, "joystick": .leftThumbstick, "stick": .leftThumbstick,
        "right stick": .rightThumbstick
    ]

    // MARK: RetroPad (Provenance, iFly)

    /// RetroPad semantics, the table Provenance and iFly use. Aliases follow RetroArch's
    /// HID autoconfig (libretro/retroarch-joypad-autoconfig, `hid/*_Switch_Online.cfg`):
    /// RetroPad B → `buttonA`, A → `buttonB`, Y → `buttonX`, X → `buttonY`, L/R →
    /// shoulders, L2/R2 → triggers, Select → `options`, Start → `menu`, menu toggle → `home`.
    ///
    /// The SNES and N64 pads' system face names are read as printed labels
    /// (``labelFaceFamilies``): Apple's "Button A" on the SNES pad is the button marked
    /// A (right), and on the N64 pad "Button B" read positionally drove what Mupen
    /// reads as C-Down. Both were tester-confirmed in Provenance (7f419ae94e,
    /// c81883fee1). The Mega Drive pad probably follows the same rule but is
    /// unverified, so it keeps the positional reading.
    public static let retroPad = MappingTable(
        commonAliases: retroPadCommonAliases,
        faceAliases: retroPadFaceAliases,
        hidButtons: retroPadHIDButtons,
        labelFaceFamilies: [.snes, .n64]
    )

    /// ``retroPad`` with every system face name read positionally, on every family.
    /// This is what iFly ships today (its port predates Provenance's two label fixes);
    /// see the proposal's open decisions before changing which one iFly uses.
    public static let retroPadSystemFaces: MappingTable = {
        var table = retroPad
        table.labelFaceFamilies = []
        return table
    }()

    private static let retroPadCommonAliases: [String: GamepadInput] = [
        "zl": .leftTrigger, "l2": .leftTrigger, "zr": .rightTrigger, "r2": .rightTrigger,
        "select": .options, "minus": .options, "back": .options, "view": .options, "mode": .options,
        "start": .menu, "plus": .menu,
        "home": .home,
        "l": .leftShoulder, "left bumper": .leftShoulder, "l1": .leftShoulder,
        "r": .rightShoulder, "right bumper": .rightShoulder, "r1": .rightShoulder
    ].merging(directionAliases) { first, _ in first }.merging(stickClickAliases) { first, _ in first }

    /// Face labels per family (RetroPad layout: B bottom, A right, Y left, X top).
    private static let retroPadFaceAliases: [PadFamily: [String: GamepadInput]] = [
        .generic: ["a": .buttonB, "b": .buttonA, "x": .buttonY, "y": .buttonX],
        .snes: ["a": .buttonB, "b": .buttonA, "x": .buttonY, "y": .buttonX],
        // N64_Nintendo_Switch_Online.cfg: A → RetroPad B, B → RetroPad Y, Z → L2, ZR → Select,
        // C buttons → right stick.
        .n64: [
            "a": .buttonA, "b": .buttonX,
            "z": .leftTrigger, "z trigger": .leftTrigger, "trigger z": .leftTrigger,
            "zr": .options,
            "c up": .rightStickUp, "cup": .rightStickUp, "c down": .rightStickDown, "cdown": .rightStickDown,
            "c left": .rightStickLeft, "cleft": .rightStickLeft, "c right": .rightStickRight,
            "cright": .rightStickRight
        ],
        // MD_Gen_Control_Pad_Switch_Online.cfg: B → RetroPad B, A → Y, Y → X, X → L, Z → R, C → A, Mode → Select.
        .megaDrive: [
            "b": .buttonA, "a": .buttonX, "y": .buttonY, "x": .leftShoulder, "z": .rightShoulder, "c": .buttonB
        ]
    ]

    private static let retroPadHIDButtons: [PadFamily: [Int: GamepadInput]] = [
        // N64_Nintendo_Switch_Online.cfg
        .n64: [
            0: .buttonX, // B
            1: .buttonA, // A
            2: .rightStickUp, // C Up
            3: .rightStickLeft, // C Left
            4: .leftShoulder, // L
            5: .rightShoulder, // R
            6: .leftTrigger, // Z
            7: .rightStickDown, // C Down
            8: .rightStickRight, // C Right
            9: .menu, // Start
            10: .options, // ZR
            12: .home // Home
        ],
        // SNES_Nintendo_Switch_Online.cfg
        .snes: [
            0: .buttonA, // B
            1: .buttonB, // A
            2: .buttonX, // Y
            3: .buttonY, // X
            4: .leftShoulder, // L
            5: .rightShoulder, // R
            6: .leftTrigger, // ZL
            8: .options, // Select
            9: .menu, // Start
            15: .rightTrigger // ZR
        ],
        // MD_Gen_Control_Pad_Switch_Online.cfg
        .megaDrive: [
            0: .buttonA, // B
            1: .buttonX, // A
            2: .buttonY, // Y
            4: .rightShoulder, // Z
            5: .buttonB, // C
            6: .leftShoulder, // X
            7: .options, // Mode
            9: .menu, // Start
            12: .home // Home
        ]
    ]

    // MARK: GameCube (iCube)

    /// GameCube / Wii semantics, the table iCube uses (its C++ twin is
    /// `ciface::iOS::PhysicalProfile`, `PhysicalProfileMapping.cpp`). Printed A/B/X/Y
    /// are the GameCube A/B/X/Y on every family, the N64 C cluster is the C-Stick, Z
    /// is the GameCube Z (`rightShoulder`, what the default GCPad profile binds
    /// Buttons/Z to), L and R are the analog triggers, ZR is Options (the app's pause
    /// route), Start is Menu and Home is Home.
    ///
    /// Knows the N64 and SNES families only; bare "Button <n>" names resolve for the
    /// N64 pad alone. On a generic pad L / R are the shoulders and ZL / ZR the
    /// triggers, as printed on a modern pad; on the Switch Online pads L / R are the
    /// GameCube analog triggers and ZR is Options.
    public static let gameCube = MappingTable(
        commonAliases: gameCubeAliases,
        faceAliases: [
            // On a modern pad L / R are the shoulders and ZL / ZR the triggers.
            .generic: gameCubeFaces.merging([
                "l": .leftShoulder, "r": .rightShoulder, "zl": .leftTrigger, "zr": .rightTrigger
            ]) { first, _ in first },
            .n64: gameCubeFaces,
            .snes: gameCubeFaces
        ],
        hidButtons: [
            // N64_Nintendo_Switch_Online.cfg
            .n64: [
                0: .buttonB, // B (RetroPad Y)
                1: .buttonA, // A (RetroPad B)
                2: .rightStickUp, // C Up
                3: .rightStickLeft, // C Left
                4: .leftTrigger, // L
                5: .rightTrigger, // R
                6: .rightShoulder, // Z → GameCube Z
                7: .rightStickDown, // C Down
                8: .rightStickRight, // C Right
                9: .menu, // Start
                10: .options, // ZR
                12: .home // Home
            ]
        ],
        families: [.generic, .n64, .snes]
    )

    private static let gameCubeFaces: [String: GamepadInput] = [
        "a": .buttonA, "b": .buttonB, "x": .buttonX, "y": .buttonY
    ]

    private static let gameCubeAliases: [String: GamepadInput] = [
        "c up": .rightStickUp, "cup": .rightStickUp, "c down": .rightStickDown, "cdown": .rightStickDown,
        "c left": .rightStickLeft, "cleft": .rightStickLeft, "c right": .rightStickRight, "cright": .rightStickRight,
        // GameCube Z: the default GCPad profile binds Buttons/Z to the right shoulder.
        "z": .rightShoulder, "z trigger": .rightShoulder, "trigger z": .rightShoulder,
        "zl": .leftShoulder,
        "zr": .options, "select": .options, "minus": .options, "back": .options, "view": .options,
        "start": .menu, "plus": .menu,
        "home": .home,
        // N64 L / R are the GameCube analog triggers.
        "l": .leftTrigger, "r": .rightTrigger,
        "left bumper": .leftShoulder, "l1": .leftShoulder,
        "right bumper": .rightShoulder, "r1": .rightShoulder,
        "l2": .leftTrigger, "r2": .rightTrigger
    ].merging(directionAliases) { first, _ in first }.merging(stickClickAliases) { first, _ in first }
}
