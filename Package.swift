// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RileyLinkIOS",
    defaultLocalization: "en",
    platforms: [.iOS(.v13), .watchOS(.v4)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "RileyLinkBLEKit",targets: ["RileyLinkBLEKit"]),
        .library(name: "RileyLinkKit",targets: ["RileyLinkKit"]),
        .library(name: "RileyLinkKitUI",targets: ["RileyLinkKitUI"]),
        .library(name: "MinimedKit",targets: ["MinimedKit"]),
        .library(name: "MinimedKitPlugin",targets: ["MinimedKitPlugin"]),
        .library(name: "OmniKitPlugin",targets: ["OmniKitPlugin"]),
        .library(name: "NightscoutUploadKit",targets: ["NightscoutUploadKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LoopKit/LoopKit.git", .branch("package-experiment2")),
        .package(url: "https://github.com/maxkonovalov/MKRingProgressView.git", .branch("master")),
        .package(url: "https://github.com/jernejstrasner/CCommonCrypto.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "RileyLinkBLEKit",
            dependencies: [ "LoopKit" ]
        ),
        .target(
            name: "RileyLinkKit",
            dependencies: [ "RileyLinkBLEKit", "LoopKit"]
        ),
        .target(
            name: "RileyLinkKitUI",
            dependencies: [
                "RileyLinkKit",
                "LoopKit",
                .product(name: "LoopKitUI", package: "LoopKit")
            ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "MinimedKit",
            dependencies: [ "RileyLinkKit", "RileyLinkBLEKit", "LoopKit" ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "MinimedKitUI",
            dependencies: [
                "MinimedKit",
                "LoopKit",
                "RileyLinkKitUI",
                .product(name: "LoopKitUI", package: "LoopKit")
            ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "MinimedKitPlugin",
            dependencies: [ "MinimedKitUI" ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "OmniKit",
            dependencies: [ "RileyLinkKit", "RileyLinkBLEKit", "LoopKit" ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "OmniKitUI",
            dependencies: [
                "OmniKit",
                "MKRingProgressView",
                "LoopKit",
                "RileyLinkKitUI", 
                .product(name: "LoopKitUI", package: "LoopKit") ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "OmniKitPlugin",
            dependencies: [ "OmniKitUI" ],
            exclude: ["Info.plist"]
        ),
        .target(
            name: "NightscoutUploadKit",
            dependencies: [ "LoopKit" ],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "MinimedKitTests",
            dependencies: ["MinimedKit"]
        ),
        .testTarget(
            name: "NightscoutUploadKitTests",
            dependencies: ["NightscoutUploadKit"]
        ),
        .testTarget(
            name: "OmniKitTests",
            dependencies: ["OmniKit"]
        ),
        .testTarget(
            name: "RileyLinkBLEKitTests",
            dependencies: ["RileyLinkBLEKit"]
        )
    ]
)
