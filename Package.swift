// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "StudyReaderMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StudyReaderMac", targets: ["StudyReaderMac"])
    ],
    targets: [
        .executableTarget(
            name: "StudyReaderMac",
            path: "Sources/StudyReaderMac"
        ),
        .testTarget(
            name: "StudyReaderMacTests",
            dependencies: ["StudyReaderMac"],
            path: "Tests/StudyReaderMacTests"
        )
    ]
)
