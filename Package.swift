// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "UIViewControllerLeakDetector",
    platforms: [.iOS(.v13), .tvOS(.v13), .macCatalyst(.v13)],
    products: [
        .library(
            name: "UIViewControllerLeakDetector",
            targets: ["UIViewControllerLeakDetector"]
        )
    ],
    targets: [
        .target(
            name: "UIViewControllerLeakDetector",
            path: ".",
            sources: ["UIViewController+TJLeakDetection.m"],
            publicHeadersPath: "."
        )
    ]
)
