// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SCNRecorder",
    platforms: [ .iOS(.v13) ],
    products: [
        .library(
            name: "SCNRecorder",
            targets: ["SCNRecorder"]),
    ],
    dependencies: [
      .package(
          url: "https://github.com/v-grigoriev/MulticastDelegate.git",
          from: "1.0.1"
      )
    ],
    targets: [
        .target(
            name: "SCNRecorder",
            dependencies: ["MulticastDelegate"],
            path: "Sources"
        )
    ]
)
