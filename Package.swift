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

import Foundation
import PackageDescription

// A version tag resolves to the prebuilt XCFrameworks from that tag's GitHub release;
// `main` always builds from source. The release workflow fills this in on the tagged
// commit only, so it stays `nil` on every branch.
// Set PV_BUILD_FROM_SOURCE=1 to build a tagged version from source instead.
let binaryRelease: (version: String, checksums: [String: String])? = nil

let environment = ProcessInfo.processInfo.environment
let buildFromSource = binaryRelease == nil || environment["PV_BUILD_FROM_SOURCE"] != nil
// The release workflow builds the frameworks it publishes from dynamic products, one
// module at a time, and names the ones already built so later modules link them
// instead of compiling them in again.
let buildingRelease = environment["PV_XCFRAMEWORK_BUILD"] != nil
let libraryType: Product.Library.LibraryType? = buildingRelease ? .dynamic : nil
let prebuilt = Set((environment["PV_XCFRAMEWORK_PREBUILT"] ?? "").split(separator: " ").map(String.init))

let module: (Target) -> Target = { source in
    prebuilt.contains(source.name)
        ? .binaryTarget(name: source.name, path: ".xcframework-build/\(source.name).xcframework")
        : source
}
// A product made only of a prebuilt framework cannot ask for a linkage type.
let libraryTypeFor: (String) -> Product.Library.LibraryType? = { module in
    prebuilt.contains(module) ? nil : libraryType
}

let sourceTargets: [Target] = [
    module(.target(name: "GamepadMapping")),
    module(.target(name: "GamepadKit", dependencies: ["GamepadMapping"]))
] + (buildingRelease ? [] : [
    .testTarget(
        name: "GamepadMappingTests",
        dependencies: ["GamepadMapping"],
        resources: [.copy("Fixtures")]
    ),
    .testTarget(name: "GamepadKitTests", dependencies: ["GamepadKit"])
])

let binaryTargets: [Target] = binaryRelease.map { release in
    release.checksums.sorted { $0.key < $1.key }.map { module, checksum in
        .binaryTarget(
            name: module,
            url: "https://github.com/Provenance-Emu/GamepadKit/releases/download/\(release.version)/\(module).xcframework.zip",
            checksum: checksum
        )
    }
} ?? []

let package = Package(
    name: "GamepadKit",
    platforms: [
        .iOS("17.4"),
        .tvOS("17.4"),
        .macCatalyst("17.4"),
        .macOS(.v14),
    ],
    // Product names are the same in both modes, so consumers never change.
    products: buildFromSource ? [
        .library(name: "GamepadMapping", type: libraryTypeFor("GamepadMapping"), targets: ["GamepadMapping"]),
        .library(name: "GamepadKit", type: libraryTypeFor("GamepadKit"), targets: ["GamepadKit"])
    ] : [
        .library(name: "GamepadMapping", targets: ["GamepadMapping"]),
        .library(name: "GamepadKit", targets: ["GamepadKit", "GamepadMapping"])
    ],
    targets: buildFromSource ? sourceTargets : binaryTargets,
    swiftLanguageModes: [.v6]
)
