// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "dock-shortcuts-mac",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "dock-shortcuts", targets: ["dock-shortcuts"])
  ],
  targets: [
    .executableTarget(
      name: "dock-shortcuts",
      path: "src"
    )
  ]
)
