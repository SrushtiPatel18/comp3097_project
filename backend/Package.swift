// swift-tools-version:5.8
// SmartPocket backend — no external package dependencies.
//
// This backend is built with a custom two-step pipeline (build.swift / run.swift)
// rather than SwiftPM, because the Replit Swift 5.8 toolchain does not include
// Foundation or a working SwiftPM resolver.  The build uses only:
//   • swiftc -c   (compile all Sources/*.swift as one module)
//   • ld.gold     (link with explicit nix store paths)
//
// To build:  swift build.swift
// To run:    swift run.swift
// Or start the "Swift Backend" workflow which calls:  cd backend && swift run.swift
//
// Runtime requirements (auto-set by run.swift via LD_LIBRARY_PATH):
//   libdispatch, libswiftCore, libswiftGlibc — all from nix store

import PackageDescription

let package = Package(
    name: "SmartPocketBackend",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SmartPocketBackend",
            path: "Sources"
        )
    ]
)
