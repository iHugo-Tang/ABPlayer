// swift-tools-version: 6.0
import PackageDescription

#if TUIST
  import struct ProjectDescription.PackageSettings

  let packageSettings = PackageSettings(
    // Customize the product types for specific package product
    // Default is .staticFramework
    // productTypes: ["Alamofire": .framework,]
    productTypes: [
      "Sentry-Dynamic": .framework,
      "WhisperKit-Dynamic": .framework,
      "KeyboardShortcuts-Dynamic": .framework,
      "Sparkle-Dynamic": .framework,
      "FirebaseCore-Dynamic": .framework,
    ]
  )
#endif

let package = Package(
  name: "ABPlayer",
  dependencies: [
    // Add your own dependencies here:
    // .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0"),
    // You can read more about dependencies here: https://docs.tuist.io/documentation/tuist/dependencies
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.0.0"),
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
    .package(url: "https://github.com/iHugo-Tang/KeyboardShortcuts", branch: "main"),
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.8.0"),
  ]
)
