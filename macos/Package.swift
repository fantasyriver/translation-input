// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TranslationInput", platforms: [.macOS(.v14)], products: [
 .executable(name: "TranslationInput", targets: ["TranslationInput"]),
 .library(name: "TranslationCore", targets: ["TranslationCore"])
], targets: [
 .target(name: "TranslationCore"),
 .executableTarget(name: "TranslationInput", dependencies: ["TranslationCore"]),
 .executableTarget(name: "CoreChecks", dependencies: ["TranslationCore"], path: "Tests/TranslationCoreTests")
], swiftLanguageModes: [.v5])
