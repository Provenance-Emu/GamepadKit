# GamepadKit

Controller handling shared by Provenance, iFly and iCube: each app wraps the pads iOS
exposes without an extended gamepad through this package and keeps only its own
`PhysicalProfileConfiguration`. [docs/PROPOSAL.md](docs/PROPOSAL.md) is the design and
the comparison of the three copies it replaced.

Version tags are prebuilt XCFrameworks
([how releases work](https://github.com/Provenance-Emu/.github/blob/main/docs/xcframework-releases.md));
`main` builds from source. iOS 17, tvOS 17, Mac Catalyst 17.

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

The three apps' configurations are mirrored in
`Tests/GamepadKitTests/AppConfigurations.swift`, and the wrapper is tested under each.

An app whose core binds the same pad from its own table (iCube's is in C++) passes
`bindingsResolver`, so the wrapper and the core cannot disagree about a button.

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

## Prebuilt XCFramework

A version tag resolves to a prebuilt XCFramework: the tag's `Package.swift` is a
`binaryTarget` pointing at the tag's GitHub Release, so an app that depends on a version
compiles none of this package. `main` and every other branch build from source.

To build a tagged version from source (to step into it in the debugger, say), set
`PV_BUILD_FROM_SOURCE=1` in the environment `xcodebuild` or Xcode starts in, then resolve
packages again.

To release, run **Release XCFramework** from the Actions tab with the new version. Do not
push version tags by hand: such a tag has no binary and builds from source.
[How releases work](https://github.com/Provenance-Emu/.github/blob/main/docs/xcframework-releases.md).
