// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ScrunchCore",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "ScrunchCore", targets: ["ScrunchCore"]),
  ],
  targets: [
    .target(name: "ScrunchCore", resources: [.copy("Resources/free-allowance.json")]),
    .testTarget(name: "ScrunchCoreTests", dependencies: ["ScrunchCore"]),
  ]
)
