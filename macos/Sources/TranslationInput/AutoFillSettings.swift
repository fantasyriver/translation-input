import AppKit
import ApplicationServices

@MainActor enum AutoFillSettings {
 static var isEnabled: Bool { AXIsProcessTrusted() && CGPreflightPostEventAccess() }
 @discardableResult static func open() -> Bool {
  if !AXIsProcessTrusted() {
   let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
   _ = AXIsProcessTrustedWithOptions(options)
  }
  let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
  return NSWorkspace.shared.open(url)
 }
}
