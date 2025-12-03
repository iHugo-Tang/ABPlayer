import ProjectDescription

let project = Project(
    name: "ABPlayer",
    targets: [
        .target(
            name: "ABPlayer",
            destinations: .macOS,
            product: .app,
            bundleId: "cc.ihugo.app.ABPlayer",
            infoPlist: .default,
            buildableFolders: [
                "ABPlayer/Sources",
                "ABPlayer/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "ABPlayerTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "cc.ihugo.app.ABPlayerTests",
            infoPlist: .default,
            buildableFolders: [
                "ABPlayer/Tests"
            ],
            dependencies: [.target(name: "ABPlayer")]
        ),
    ]
)
