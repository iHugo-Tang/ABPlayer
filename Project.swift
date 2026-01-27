import ProjectDescription

let buildVersionString = "69"
let shortVersionString = "0.2.10"
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
        "CFBundleVersion": .string(buildVersionString),
        "CFBundleShortVersionString": .string(shortVersionString),
        "NSMainStoryboardFile": "",
        "SUFeedURL":
          "https://github.com/sunset-valley/ABPlayer/releases/latest/download/appcast.xml",
        "SUEnableAutomaticChecks": true,
        "SUPublicEDKey": "Zw9DuoU9cuGJGt81eRRfWq5OwhCG+udkeOBwScjchU0=",
      ]),
      buildableFolders: [
        "ABPlayer/Sources",
        "ABPlayer/Resources",
      ],
      dependencies: [
        .sdk(name: "AppIntents", type: .framework, status: .optional),
        .external(name: "Sentry"),
        .external(name: "WhisperKit"),
        .external(name: "KeyboardShortcuts"),
        .external(name: "Sparkle"),
        .external(name: "TelemetryDeck"),
      ],
    ),
    .target(
      name: "ABPlayerDev",
      destinations: .macOS,
      product: .app,
      bundleId: "cc.ihugo.app.ABPlayerDev",
      deploymentTargets: .macOS("15.7.2"),
      infoPlist: .extendingDefault(with: [
        "CFBundleVersion": .string(buildVersionString),
        "CFBundleShortVersionString": .string(shortVersionString),
        "NSMainStoryboardFile": "",
        "SUFeedURL":
          "https://github.com/sunset-valley/ABPlayer/releases/latest/download/appcast.xml",
        "SUEnableAutomaticChecks": true,
        "SUPublicEDKey": "Zw9DuoU9cuGJGt81eRRfWq5OwhCG+udkeOBwScjchU0=",
      ]),
      buildableFolders: [
        "ABPlayer/Sources",
        "ABPlayer/Resources",
      ],
      dependencies: [
        .sdk(name: "AppIntents", type: .framework, status: .optional),
        .external(name: "Sentry"),
        .external(name: "WhisperKit"),
        .external(name: "KeyboardShortcuts"),
        .external(name: "Sparkle"),
        .external(name: "TelemetryDeck"),
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
