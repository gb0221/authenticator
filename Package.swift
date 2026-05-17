// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Authenticator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Authenticator",
            path: "Sources/Authenticator"
        ),
        .testTarget(
            name: "AuthenticatorTests",
            dependencies: ["Authenticator"],
            path: "Tests/AuthenticatorTests"
        )
    ]
)
