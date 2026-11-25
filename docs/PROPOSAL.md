# GamepadKit: one controller package for iFly, iCube and Provenance

Status: proposal with a working first cut, in a local git repository. It has no remote,
nothing is pushed, and none of the three apps depends on it. Written 2026-11-24.

## Recommendation

Yes, make controllers a shared package, and start with the two layers built here.

- The three apps carry the same "physical profile controller" three times, and the copies
  have already drifted in ways nobody chose (section 1). Two fixes Provenance made for the
  Switch Online SNES and N64 pads never reached iFly. A fix iCube made this week to the
  generic-pad fallback is in neither of the other two.
- The parts that really differ between apps are small and nameable: the name table, where
  a button lands, how pause is detected and delivered, and which pads get wrapped. In this
  package each one is a value the app passes in. The three apps' own test suites pass
  against it unchanged in substance (105 tests).
- iFly should adopt last, after 1.0 ships. Nothing here needs iFly to change now.

The name is **GamepadKit**. The app-neutral shared packages are named `<Thing>Kit`
(SkinKit, ContinuityKit); the `PV` prefix marks packages that began inside Provenance
(PVWebServer, PVSystems). This one is app-neutral from the start. "ControllerKit" reads as
view controllers, and Apple owns "GameController".

## What was read

| App | Code | Version |
|---|---|---|
| iFly | `Sources/Core/Input/PhysicalProfile/` (10 files), `Sources/Core/Input/Clamshell/` | develop `7fffe2160` |
| Provenance | `PVSupport/Sources/PVSupport/Controller/PhysicalProfile/` (3 files) | branch `claude/eager-mayer-1f10ef`, `13777401fe` (the generic-pad port, committed, not merged) |
| iCube | `Source/iOS/App/Common/Swift/Controllers/PhysicalProfile/` (2 files), `Source/Core/InputCommon/ControllerInterface/iOS/PhysicalProfileMapping.{h,cpp}`, `DOLPhysicalProfileBridge` | develop `aa9ff9ac13` plus the **uncommitted** generic-pad port in worktree `claude/reverent-golick-ae1cf2` |

The iCube port was still being written when it was read. Its tests are copied into this
package as they stood; if that session changes them before it lands, re-copy
(`Tests/GamepadMappingTests/ICubeMappingTests.swift` says how).

## 1. Comparison of the three copies

### 1.1 Equivalent in intent

These do the same job in all three apps and differ only in names, access level and
formatting.

| Piece | iFly | Provenance | iCube |
|---|---|---|---|
| Input enum (dpad, sticks, face, shoulders, triggers, menu/options/home, stick clicks, C cluster) | `PhysicalProfileInput` | `PVSynthesizedInput` | `SynthesizedInput` (Swift), `Input` (C++) |
| Name normalising (lowercase, `-`/`_` to space, collapse spaces, drop "button ") | yes | yes | yes, twice (Swift calls the C++) |
| Resolution order: system names, then printed labels, then "Button n" through RetroArch's HID autoconfig | yes | yes | yes |
| "Standard names win, then alphabetical; one element per input" | yes | yes | yes |
| Usable = a direction input and a face button | yes | yes | yes |
| Positional fallback for a plain HID pad (leftover directions, then numbered buttons as A, B, X, Y, L, R, L2, R2, Select, Start, L3, R3, then trigger axes) | yes | yes | yes, in C++ |
| Trigger axis that rests at 0 or at -1 | yes | yes | yes |
| N64 C cluster presented as the right stick | yes | yes | yes |
| Synthesized extended gamepad with settable button, axis and direction-pad elements | 4 classes | 1 class on Provenance's iCade elements | 4 classes in one file |
| Wrapper: a `GCController` subclass that returns the synthesized gamepad, is its own `capture()`, forwards haptics/light/battery/motion | yes | yes | yes |
| Select + Start as the pause chord for a pad with no Home | yes | yes | yes, SNES family only |

### 1.2 Where they diverged, and why

**Name tables.** iFly and Provenance share one RetroPad table (RetroPad B is the bottom
button, so printed B drives `buttonA`). iCube's is a different table on purpose: printed
A/B/X/Y are the GameCube A/B/X/Y, N64 Z is the GameCube Z (`R Shoulder`), N64 L/R are the
analog triggers, ZR is Options. iCube also knows no Mega Drive pad, and resolves bare
"Button n" names for the N64 pad only.

**The SNES and N64 face buttons (not chosen, just drifted).** Provenance reads those two
pads' system names ("Button A") as the printed label, after testers found A/B and X/Y
swapped on the SNES pad (`7f419ae94e`) and N64 B dead (`c81883fee1`). iFly was ported
from the commit before those (`1133601a77`) and still reads them as positions. So on the
same SNES pad, the button marked A drives `buttonB` in Provenance and `buttonA` in iFly.
iCube reads them as positions too. See open decision 1.

**iCube's C++ twin.** Dolphin's input layer binds the real pad itself
(`MFiController::AddPhysicalProfileInputs`), so the table has to exist in C++. The Swift
wrapper exists only for the app's menus, hub and pause routes, and reads the same table
through an Objective-C bridge. iFly and Provenance have no such split: their cores read
the wrapper's `extendedGamepad`.

**Routing (iFly only).** iFly re-routes buttons for the Dreamcast: shoulders drive the
analog triggers on a pad with no ZL/ZR (while still reporting L/R to menus), Select is
chord-only and never reaches flycast, and on tvOS Start drives Options because flycast's
tvOS default puts Dreamcast Start there. Provenance and iCube pass every button straight
through.

**Pause.** All three detect a trigger and then disagree about everything after:

| | iFly | Provenance | iCube |
|---|---|---|---|
| Trigger | Home, else Select + Start | same | Home; Select + Start for the SNES pad only; Start alone when there is no Options; otherwise the app's ordinary Options route |
| Delivered through | `onPauseRequested` closure | `controllerPausedHandler` | `controllerPausedHandler` for Home, `pauseRequestHandler(reason)` for the chord and Start |
| Trigger buttons held back from the game after it fires | yes | yes | no |
| Lone Select tap reported (Insert Coin) | yes | no | no |

**Which optional buttons the synthesized pad reports.** Each app keys something off
whether `buttonOptions` / `buttonHome` is nil. iFly always reports Options (flycast's
default Start placement needs it) and hides Home when it is the pause button. Provenance
reports both when the pad has them. iCube hides Options when it is part of the chord, so
Select alone cannot pause through the Options route.

**Which pads are wrapped.** All require no extended gamepad, usable bindings, and not a
remote. Beyond that: iFly wraps anything; Provenance refuses a generic pad that has a
micro profile unless it has a B or Y button (a remote with an unknown category stays a
remote); iCube refuses any generic pad that has a micro profile.

**Smaller differences**

| | iFly | Provenance | iCube |
|---|---|---|---|
| Button handler order on a change | value, then pressed | iCade elements (per a note in iFly's port they share one handler slot; not re-checked) | pressed, then value |
| `playerIndex` | stored on the wrapper, forwarded to the pad | same | read from and written to the pad only |
| Name for an unnamed pad | "`<category>` Gamepad" | same, "Gamepad" when the category is empty | same, "Unknown Controller" when empty |
| System gesture disabled on | Start, Select, Home | Start, Select | every bound button, plus the pad's micro-gamepad Menu and a no-op paused handler on the real pad |
| `unbind()` on disconnect | yes | no | no |
| Objective-C surface | none | `@objc(PVPhysicalProfileController)`; `PVIsPhysicalProfileController` reads `base` by KVC | `DOLPhysicalBaseController` protocol |
| Trigger-axis math, wrap rule, fallback name | in the controller | moved into the pure mapping file, tested | in C++, tested through the bridge |
| "A button named Hat must not take the D-pad" (kind check in the positional fallback) | no | no | yes (new this week) |
| Registry of wrappers | static enum with a lock | inside `PVControllerManager` | inside `ControllerManager` |

### 1.3 What each app needs that the others do not

- **iFly:** the Dreamcast routing above; the lone-Select tap; the clamshell-dock catalog
  and the window-shortening `ClamshellScreenCover`; handing the wrapper to flycast's
  `ios_gamepad_add_controller`, which holds it weakly.
- **iCube:** the mapping in C++ for the core; MFi input-name strings ("L Stick", "R Stick
  Y+") as the common vocabulary of core and app; resolving a wrapper back to its real pad
  before looking up the core device; Wii pointer and DSU motion.
- **Provenance:** an Objective-C-visible class for its native core bridges; many cores, so
  per-system remapping (`PVRemappableController`); iCade, Steam Controller, gyro mouse,
  light bar, configurable pause triggers and tvOS Menu handling (section 2, layer c).

## 2. The package boundary

### Layer (a): `GamepadMapping`. Built.

Foundation only. No GameController import, so it tests on any host in milliseconds.

| Type | What it is |
|---|---|
| `GamepadInput`, `PadFamily` | the input enum and family detection |
| `MappingTable` | the name tables as data: `.retroPad` (Provenance), `.retroPadSystemFaces` (iFly today), `.gameCube` (iCube) |
| `PhysicalProfileMapping` | resolver over a table: by name, positional fallback, usability, remote test, fallback name |
| `PauseTrigger`, `PausePolicy`, `PauseTriggerTracker`, `LoneTapTracker` | which trigger a pad gets, and the state machine that fires it once |
| `TriggerAxis` | the 0-rest / -1-rest axis math |
| `WrapPolicy`, `WrapCandidate` | the three apps' "should this pad be wrapped" rules |
| `InputRouter`, `InputRoute`, `RoutingContext` | the hook for per-app routing |
| `OptionalElementExposure` | when Options / Home are reported |
| `ClamshellDockCatalog`, `ClamshellDockMode` | iFly's catalog and cover-height maths |

On adoption each app deletes:

- **iFly:** `PhysicalProfileMapping.swift`, `PhysicalProfileInput.swift`,
  `PhysicalProfilePad.swift`, `PhysicalProfilePauseTrigger.swift`,
  `ClamshellDockCatalog.swift`, the mode enum in `ClamshellDockPrefs.swift`, and both test
  files (about 380 lines of source, 160 of tests).
- **Provenance:** `PVPhysicalProfileMapping.swift` and its tests (about 400 and 410 lines).
- **iCube:** nothing by itself. Its Swift side has no table to delete; the table is in
  C++. See open decision 2.

Risk: low. The layer is pure and each app's existing tests run against it here. The one
behaviour change is the kind check taken from iCube: in the positional fallback a button
can no longer claim a direction input by name, or a direction element a button input.
Before, such an element was bound in the table and then dead in the wrapper (the element
cast fails), so this can only turn a dead control into a working one. It is the single
place the package does not reproduce iFly's and Provenance's copies exactly.

### Layer (b): `GamepadKit`. Built.

Imports GameController and re-exports layer (a).

| Type | What it is |
|---|---|
| `SynthesizedButtonInput`, `SynthesizedAxisInput`, `SynthesizedDirectionPad`, `SynthesizedExtendedGamepad` | the settable elements, from iFly's (separate value and pressed handler slots) |
| `PhysicalProfileController` | the wrapper |
| `PhysicalProfileConfiguration` | everything that differs per app: table, wrap policy, pause policy, router, hold-back, exposure, system-gesture set, legacy paused handler, handler order, player-index storage, unnamed-pad name, remote test, log sink |
| `PhysicalProfileControllerRegistry` | lock-protected wrapper store with `substituting(_:)` |

The package ships no app's configuration. The three configurations that reproduce today's
behaviour are in `Tests/GamepadKitTests/AppConfigurations.swift`, including iFly's
Dreamcast router (about 30 lines), and are what each adoption PR would move into the app.
The wrapper is tested end to end under all three, against a fake pad built from the
package's own settable elements.

On adoption each app deletes:

- **iFly:** the rest of `Sources/Core/Input/PhysicalProfile/` (about 560 lines). It keeps
  its configuration and router, and `ClamshellScreenCover` and `ClamshellDockPrefs`.
- **Provenance:** `PVPhysicalProfileController.swift` and `PVSynthesizedGamepad.swift`
  (about 320 lines). It keeps the iCade element classes for iCade itself, and changes
  `PVIsPhysicalProfileController` to look for the new Objective-C class name
  (`GPKPhysicalProfileController`; `base` stays reachable by KVC).
- **iCube:** `PhysicalProfileController.swift` and `SynthesizedGamepad.swift` (about 530
  lines with the port in progress), and `SelectStartChord`. It keeps the micro-gamepad Menu neutering and the no-op
  paused handler as a few lines run after wrapping, and adds the `DOLPhysicalBaseController`
  conformance in an extension.

Risk: medium, and it is all in the wrapper's edges, which no unit test on a Mac can see.
Specifically: tvOS system-gesture behaviour on a real Switch Online pad; the handler
order iCube asserts; `playerIndex` on a pad that ignores it; and Provenance moving off
its iCade element classes for the synthesized pad. Each needs one device pass per app with
an SNES pad and a plain HID pad. The wrapper is `@unchecked Sendable` with unsynchronised
state touched from the GameController handler queue, exactly as all three copies are
today; the package does not make that better or worse.

### Layer (c): candidates for later

| Candidate | Today | Recommendation |
|---|---|---|
| **Case / clamshell controllers** | iFly: `ClamshellDockCatalog` (FlipPad, Pocket Taco, by name, with cover height) and `ClamshellScreenCover`. Provenance: `CaseControllerDetector` (380 lines; Pocket Taco, Soolra, passive cases matched through skins). Two catalogs of the same hardware. | **Next after (b).** Merge the two catalogs in layer (a), keyed by name with an optional cover height. Move `ClamshellScreenCover` into a small UIKit target once a FlipPad has been measured; it is untested on hardware today. |
| **Pause triggers** | Provenance: `PauseMenuTrigger` and `PauseMenuTriggerMonitor` (touchpad click, share button, L3 + R3, Select + Start, Home, lone Menu; user-selectable). iCube: `PauseGestureTracker` (345 lines, shoulder + Menu gestures, Menu press ownership). iFly: fixed bindings in `GameControllerManager`. | **Yes, as its own step.** The pure part (the trigger enum and the tracker here) is already in layer (a) and should grow to cover Provenance's list. The monitors stay per app until two apps want the same one. This is where "menu handling on tvOS" belongs. |
| **tvOS Menu handling** | Three different answers to "who owns a Menu press": iCube's `MenuPressOwnership`, Provenance's monitor, iFly's hard-bound Menu pause. | **Share the rule, not the code, for now.** Write the ownership rule down once and port iCube's `MenuPressOwnership` (pure, about 20 lines) into layer (a). Do not try to unify the view-controller plumbing. |
| **Gyro and touchpad** | Provenance: `GyroMouseAdapter` (403 lines, tested), `ControllerPointerRouter`, `ControllerMotionRouter`. iCube: `GyroPointerMath` (pure), `PointerSource`, `RemotePointerBinding`. | **Share the maths only.** Dead zone, low-pass and accumulate-to-cursor are pure and duplicated; they fit a `GamepadMotion` target with no GameController import. The adapters are bound to each app's core interface (`MouseResponder`, Wii IR) and stay where they are. |
| **Light bar** | Provenance only: `ControllerLightBarManager` (331 lines). | **Move when a second app wants it.** It is self-contained and would move as is. Not worth a package dependency for one consumer. |
| **iCade** | Provenance only: 12 files, 1,150 lines in `PVSupport/Controller/iCade`. | **Leave in Provenance.** Old, working, one consumer, and keyboard-driven rather than GameController-driven. The one useful step: rebuild its elements on the package's `Synthesized*` classes when Provenance adopts layer (b), which removes the shared handler slot. |
| **Steam Controller** | Provenance only, behind `canImport(SteamController)`, not on Catalyst. A separate package already exists (`../SteamController`). | **Leave as it is.** It is already a package. If iFly or iCube want it, they add the same optional hook; the hook is about 20 lines. |
| **DSU** | Already a package (`PVControllerDSU`); iCube has its own `DSUSettings`. | **No change.** Not part of this package. |
| **Remap storage** | Provenance: `PVRemappableController` (673 lines, per system). iCube: `Remap/RemapModel` writing Dolphin profiles. iFly: flycast mapping files named by vendor name. | **Do not share.** The three stores are shaped by three cores. What can be shared is the identity they key on: one function that names a pad (`fallbackVendorName` today). Unify that first (open decision 4). |

## 3. Adoption order

1. **Provenance first, layer (a) then (b).** It is the original, it has the widest set of
   cores to shake out a wrong mapping, its copy is the simplest (identity routing), and it
   is not about to go through App Review. Adopting (a) alone is a delete-and-import with
   its own 33 tests as the check.
2. **iCube second.** Layer (b) for the Swift wrapper is straightforward. Layer (a) depends
   on open decision 2, because the core needs the table in C++.
3. **iFly last, after 1.0 is approved.** iFly's copy is the newest and is what this package
   was built from, so it gains the least and risks the most by moving now. When it does
   move, the test of success is that `AppConfigurations.iFly()` plus the package behave as
   iFly does today.

Before step 1: create `Provenance-Emu/GamepadKit`, push, tag `0.1.0`. Consume by URL and
tag, as the other shared packages are.

## 4. Decisions that are the owner's

1. **Should iFly read the SNES and N64 pads' face buttons as printed labels, as Provenance
   does?** Today the SNES button marked A is Dreamcast A in iFly. With Provenance's rule it
   would be Dreamcast B, and the bottom button (marked B) would be Dreamcast A, which
   matches by position. Neither is obviously right for a Dreamcast, whose labels match
   Xbox's, not Nintendo's. The package has both tables; iFly's configuration picks one.
   Changing it changes shipping behaviour, so it is not changed here.
2. **How does iCube's C++ core get the shared table?** Three options: (i) keep the C++
   table as a deliberate second copy and add a test that checks it against the package's
   `.gameCube` table; (ii) have the core call the Swift package through an `@objc` facade,
   which means the CMake-built core depends on a Swift module; (iii) generate the C++ table
   from the Swift one at build time. Recommendation: (i). It is one test, and it removes
   the drift without touching Dolphin's build.
3. **Should iCube's generic-pad wrap rule match the others?** iCube refuses every generic
   pad that has a micro profile; Provenance allows one that has a B or Y button; iFly
   allows all. Provenance's is the most careful. The package keeps all three.
4. **One name for an unnamed pad.** "Gamepad", "Unknown Controller" and " Gamepad" (iFly,
   empty category) are three keys for the same pad in three apps' saved mappings. Picking
   one renames saved mappings in the apps that change.
5. **Button handler order.** iFly fires value then pressed, iCube pressed then value. The
   package makes it a setting. If nothing in iCube depends on its order, drop the setting
   and use one.
6. **Package name and home.** GamepadKit under `Provenance-Emu`, as proposed, or something
   else.
7. **Licence.** iCube's files carry GPL-2.0-or-later headers; iFly's and Provenance's carry
   none. The package's code came from iFly's copy, with one rule (the kind check) and one
   table re-expressed from iCube's. Pick the licence before the repository is public.

## 5. What could not be reconciled

These are differences the package carries as configuration rather than resolves. Each is
a place where the three apps do different things and no evidence here says which is right.

- The SNES / N64 face-button reading (decision 1).
- iCube's table living in C++ (decision 2). The package's `.gameCube` table is a
  re-expression checked by iCube's own tests, not a replacement for the C++.
- Pause delivery: three callback shapes, and whether the trigger's buttons are held back.
- Whether Options and Home are reported, which each app's pause routing depends on.
- Button handler order, `playerIndex` storage, and the unnamed-pad name.
- Provenance's use of its iCade element classes for the synthesized pad. The package uses
  iFly's elements; whether anything in Provenance relies on the iCade classes' behaviour
  was not checked.
- iCube binds a remote's elements by name alone and never by position. In the package the
  wrapper never sees a remote (every wrap policy refuses one), so the rule lives only in
  iCube's core and in the test shim.
- Two small threshold differences in trigger-axis handling: iFly treats an axis as resting
  at -1 at bind time only below -0.5, Provenance and iCube below -0.05. The package uses
  iFly's at bind time and -0.05 afterwards, as iFly does.

## 6. The first cut

```
GamepadKit/
  Package.swift                 iOS 17.4, tvOS 17.4, Mac Catalyst 17.4 (macOS 14 for host tests), Swift 6
  Sources/GamepadMapping/       layer (a), 10 files
  Sources/GamepadKit/           layer (b), 8 files
  Tests/GamepadMappingTests/    iFly's, Provenance's and iCube's mapping tests, plus policy tests
  Tests/GamepadKitTests/        iCube's element tests, the wrapper end to end, the three app configurations
```

Checked on 2026-11-24:

- `xcrun swift test`: 105 tests, 0 failures (87 mapping, 18 GameController layer).
- `xcodebuild build` of both library targets for iOS Simulator, tvOS Simulator and Mac
  Catalyst: all succeed with no warnings, Swift 6 language mode.
- `swiftlint`: clean (the verbatim-ported test files are excluded so they stay diffable).

Not checked: anything on a device or with a real controller. The wrapper tests use a fake
pad. Use `xcrun swift`, not a bare `swift`: on this machine the first `swift` on `PATH` is
a 5.3 toolchain.

Where the ported tests came from:

| Package test file | Source | Tests |
|---|---|---|
| `IFlyMappingTests.swift`, `ClamshellDockCatalogTests.swift` | iFly `Tests/`, develop `7fffe2160` | 11 + 2 |
| `ProvenanceMappingTests.swift` | Provenance `PVSupportTests/PVPhysicalProfileMappingTests.swift`, `13777401fe` | 33 |
| `ICubeMappingTests.swift`, `ICubeSynthesizedElementTests.swift` | iCube `DolphiniOSTests/PhysicalProfileMappingTests.swift`, uncommitted worktree copy | 36 + 6 |

One iCube test was left out (`testUnnamedPadIsNamedByItsProductCategory`): its expected
text is iCube's own and is now passed in. iCube's tests run through
`Tests/GamepadMappingTests/ICubeShims.swift`, which maps iCube's bridge calls and MFi
names onto the package; the test bodies are otherwise unchanged apart from type renames.
