// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Invocat",
    products: [
        .library(name: "LibInvocat", targets: ["LibInvocat"]),
        .executable(name: "invocat", targets: ["invocat"])
    ],
    targets: [
        .target(name: "LibInvocat"),
        .target(name: "invocat", dependencies: ["LibInvocat"]),
        .testTarget(name: "LibInvocatTests", dependencies: ["LibInvocat"])
    ]
)

// Requires macOS 10.11 or newer:
// swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.11"
