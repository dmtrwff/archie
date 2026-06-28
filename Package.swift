// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Archie",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Archie", targets: ["Archie"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.13.0"),
    ],
    targets: [
        .executableTarget(
            name: "Archie",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/Archie",
            exclude: ["Archie.icon"],
            resources: [.process("Resources")]
        ),
    ]
)
