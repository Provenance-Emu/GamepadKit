// swift-tools-version: 6.0
//
// GamepadKit: controller handling shared by Provenance, iFly and iCube.
//
// Modules, in dependency order:
//   GamepadMapping  element names to inputs, positional fallback, pad family detection,
//                   pause triggers, wrap rules, clamshell-dock catalog. Foundation only:
//                   no GameController import, so it tests on any host.
//   GamepadKit      the synthesized extended gamepad and its elements, the wrapping
//                   controller and a registry. Per-app behaviour (mapping table, routing,
//                   pause delivery) is passed in as a configuration.
//
// macOS is listed only so `swift test` runs on the host without a simulator.
// The apps ship on iOS, tvOS and Mac Catalyst.

import PackageDescription

let package = Package(
    name: "GamepadKit",
    platforms: [
        .iOS("17.4"),
        .tvOS("17.4"),
        .macCatalyst("17.4"),
        .macOS(.v14),
    ],
    products: [
        .library(name: "GamepadMapping", targets: ["GamepadMapping"]),
        .library(name: "GamepadKit", targets: ["GamepadKit"]),
    ],
    targets: [
        .target(name: "GamepadMapping"),
        .target(name: "GamepadKit", dependencies: ["GamepadMapping"]),
        .testTarget(
            name: "GamepadMappingTests",
            dependencies: ["GamepadMapping"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "GamepadKitTests", dependencies: ["GamepadKit"]),
    ],
    swiftLanguageModes: [.v6]
)
