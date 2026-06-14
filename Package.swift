// swift-tools-version: 6.0
//
//  Package.swift
//  IRefresh
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "IRefresh",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IRefresh", targets: ["IRefresh"]),
    ],
    targets: [
        .target(name: "IRefresh", resources: [.process("Resources")]),
        .testTarget(name: "IRefreshTests", dependencies: ["IRefresh"]),
    ]
)
