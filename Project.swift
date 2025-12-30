import ProjectDescription

let project = Project(
  name: "ABPlayer",
  settings: .settings(
    base: [
      "SWIFT_VERSION": "6.2"
    ],
    configurations: [
      .debug(name: "Debug"),
      .release(name: "Release"),
    ]
  ),
  targets: [
    .target(
      name: "ABPlayer",
      destinations: .macOS,
      product: .app,
      bundleId: "cc.ihugo.app.ABPlayer",
      deploymentTargets: .macOS("15.7.2"),
      infoPlist: .extendingDefault(with: [
        "CFBundleVersion": "nightly-f1e431b",
        "CFBundleShortVersionString": "0.2.0",
        "NSMainStoryboardFile": "",
      ]),
      buildableFolders: [
        "ABPlayer/Sources",
        "ABPlayer/Resources",
      ],
      dependencies: [
        .external(name: "Sentry-Dynamic"),
        .external(name: "WhisperKit"),
        .external(name: "KeyboardShortcuts"),
      ],
    ),
    .target(
      name: "ABPlayerTests",
      destinations: .macOS,
      product: .unitTests,
      bundleId: "cc.ihugo.app.ABPlayerTests",
      deploymentTargets: .macOS("15.7.2"),
      infoPlist: .default,
      buildableFolders: [
        "ABPlayer/Tests"
      ],
      dependencies: [.target(name: "ABPlayer")]
    ),
  ]
)
