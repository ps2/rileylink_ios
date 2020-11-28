// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RileyLinkIOS",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "RileyLinkBLEKit",targets: ["RileyLinkBLEKit"]),
        .library(name: "RileyLinkKit",targets: ["RileyLinkKit"]),
        .library(name: "RileyLinkKitUI",targets: ["RileyLinkKitUI"]),
        .library(name: "MinimedKit",targets: ["MinimedKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LoopKit/CGMBLEKit.git", .branch("package-experiment")),
        .package(url: "https://github.com/LoopKit/G4ShareSpy.git", .branch("package-experiment")),
        .package(name: "ShareClient", url: "https://github.com/LoopKit/dexcom-share-client-swift.git", .branch("package-experiment")),
        .package(url: "https://github.com/LoopKit/LoopKit.git", .branch("package-experiment")),
        .package(url: "https://github.com/maxkonovalov/MKRingProgressView.git", .branch("master")),
        .package(url: "https://github.com/jernejstrasner/CCommonCrypto.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "RileyLinkBLEKit",
            dependencies: [ "LoopKit" ],
            path: "RileyLinkBLEKit",
            exclude: ["Info.plist"],
            sources: ["RileyLinkBLEKit", "Common"]
        ),
        .target(
            name: "RileyLinkKit",
            dependencies: [ "RileyLinkBLEKit", "LoopKit"],
            path: "RileyLinkKit",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "RileyLinkKitUI",
            dependencies: [
                "RileyLinkKit",
                "LoopKit",
                .product(name: "LoopKitUI", package: "LoopKit")
            ],
            path: "RileyLinkKitUI",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "MinimedKit",
            dependencies: [ "RileyLinkKit", "RileyLinkBLEKit", "LoopKit" ],
            path: "MinimedKit",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "OmniKit",
            dependencies: [ "RileyLinkKit", "RileyLinkBLEKit", "LoopKit" ],
            path: "OmniKit",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "OmniKitUI",
            dependencies: [ "OmniKit", "MKRingProgressView" ],
            path: "OmniKitUI",
            exclude: ["Info.plist"],
            sources: ["OmniKitUI", "Common"]
        ),
        .testTarget(
            name: "RileyLinkBLEKitTests",
            dependencies: ["RileyLinkBLEKit"],
            path: "RileyLinkBLEKitTests",
            exclude: ["Info.plist"],
            sources: ["RileyLinkBLEKitTests", "Common"]
        ),
    ]
)
