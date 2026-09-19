// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "dock-numbers",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(
      name: "dock-numbers",
      path: "Sources/dock-numbers"
    )
  ]
)
