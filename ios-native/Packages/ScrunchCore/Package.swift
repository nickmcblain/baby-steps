// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ScrunchCore",
  defaultLocalization: "en-GB",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "ScrunchCore", targets: ["ScrunchCore"]),
  ],
  targets: [
    .target(name: "ScrunchCore", resources: [.process("Localizable.xcstrings")]),
    .testTarget(name: "ScrunchCoreTests", dependencies: ["ScrunchCore"]),
  ]
)
