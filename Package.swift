// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "LibInvocat",
    products: [
        .library(
            name: "LibInvocat",
            targets: ["LibInvocat"]),
    ],
    targets: [
        .target(
            name: "LibInvocat",
            path: "Sources"),
        .testTarget(
            name: "LibInvocatTests",
            dependencies: ["LibInvocat"],
            path: "Tests")
    ]
)

// swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.11"
