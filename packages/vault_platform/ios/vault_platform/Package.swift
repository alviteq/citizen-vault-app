// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vault_platform",
    platforms: [.iOS("13.0")],
    products: [.library(name: "vault-platform", targets: ["vault_platform"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "vault_platform",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)

