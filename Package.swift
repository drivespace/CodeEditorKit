// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeEditorKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodeEditorKit", targets: ["CodeEditorKit"]),
    ],
    targets: [
        .target(name: "CodeEditorKit"),
        .executableTarget(name: "CodeEditorDemo", dependencies: ["CodeEditorKit"]),
        .testTarget(name: "CodeEditorKitTests", dependencies: ["CodeEditorKit"]),
    ]
)
