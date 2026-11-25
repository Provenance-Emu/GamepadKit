# GamepadKit

Controller handling shared by Provenance, iFly and iCube. A first cut (`0.1.0`); no app
depends on it yet. Read [docs/PROPOSAL.md](docs/PROPOSAL.md) first.

Two modules:

- **GamepadMapping**: element names to inputs, positional fallback for plain HID pads, pad
  family detection, pause triggers, wrap rules, clamshell-dock catalog. Foundation only.
- **GamepadKit**: a synthesized extended gamepad for pads iOS exposes without one (Switch
  Online SNES/N64/Mega Drive pads, generic USB/Bluetooth pads), the controller that wraps
  them, and a registry. What differs per app is passed in as a `PhysicalProfileConfiguration`.

```swift
import GamepadKit

let configuration = PhysicalProfileConfiguration(
    mapping: PhysicalProfileMapping(table: .retroPad),
    wrapPolicy: .usablePadNotRemoteLike,
    pausePolicy: .homeOrSelectStart
)

if PhysicalProfileController.isNeeded(for: controller, configuration: configuration) {
    let wrapper = PhysicalProfileController(wrapping: controller, configuration: configuration)
    wrapper.onPauseRequested = { _ in /* open the pause menu */ }
    PhysicalProfileControllerRegistry.shared.register(wrapper)
    // hand `wrapper` to whatever reads `extendedGamepad`
}
```

The configuration each app would use to match its current behaviour is in
`Tests/GamepadKitTests/AppConfigurations.swift`.

## D-pad as stick

For a pad with a D-pad and no stick (8BitDo FlipPad and similar) in games that read only
the stick. Off unless the configuration sets it:

```swift
configuration.dpadStick = DpadStickSettings(
    mode: nil,                    // automatic: D-pad + stick when the pad has no stick
    response: .defaultRamp,       // a tap is 40%, full after 0.2 s; or .full
    modifier: .leftShoulder,      // hold to halve the stick (walk)
    modeChord: .options           // Select + D-pad up / down cycles the mode
)
wrapper.onDpadModeChanged = { mode in /* show it, save it */ }
```

Modes are `.dpad`, `.leftStick` and `.both`; `wrapper.dpadMode` reads and sets the current
one. Diagonals are scaled to the unit circle. The wrapper runs its own timer while a ramp
is moving.

## Testing

```bash
xcrun swift test
```

Use `xcrun swift` so the Xcode toolchain is picked up (Swift 6 is required).

## Licence

MIT. See [LICENSE](LICENSE).
