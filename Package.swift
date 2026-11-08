// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let settings: [SwiftSetting] = [
   .enableUpcomingFeature("ApproachableConcurrency"),
]

let package = Package(
   name: "junkdrawer",
   platforms: [.macOS("27.0")],
   targets: [
      .target(name: "JunkdrawerCore", swiftSettings: settings),
      .executableTarget(name: "junkdrawer", dependencies: ["JunkdrawerCore"], swiftSettings: settings),
      .executableTarget(name: "gen", swiftSettings: settings),
   ]
)
