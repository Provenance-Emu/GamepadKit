# GamepadKit

Controller handling shared by Provenance, iFly and iCube. A local first cut: not yet a
repository, and no app depends on it. Read [docs/PROPOSAL.md](docs/PROPOSAL.md) first.

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

## Testing

```bash
xcrun swift test
```

Use `xcrun swift` so the Xcode toolchain is picked up (Swift 6 is required).
