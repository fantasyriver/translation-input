import AppKit
import TranslationCore

// Appended to App.swift in the offline review build so this extension can exercise
// the production layout and result presenter without adding a shipping test API.
enum Credentials {
 static func read(configuration: LLMConfiguration) -> String? { nil }
 static func save(_ value: String, configuration: LLMConfiguration) throws {
  throw NSError(domain: "UIReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "离线预览使用固定样例。"])
 }
}
extension AppDelegate {
 func startReview() {
  NSApp.setActivationPolicy(.regular); NSApp.appearance = NSAppearance(named: .aqua)
  configureMenu(); configurePanel(); openPanel(captureTarget: false)
  input.string = "你好，很高兴认识你。\n期待我们一起，把这个想法变成现实。"; updateInputState()
  submit.target = self; submit.action = #selector(reviewTranslate)
  input.submit = { [weak self] in self?.reviewTranslate() }
  let appearance = NSMenuItem(title: "切换深浅色", action: #selector(reviewAppearance), keyEquivalent: "d")
  appearance.target = self; NSApp.mainMenu?.items.first?.submenu?.addItem(appearance)
 }
 @objc private func reviewTranslate() {
  if busy { cancelWork(); status.stringValue = "已取消，原文已保留。"; return }
  setBusy(true); resultView.markPrevious(); status.stringValue = "正在翻译离线样例…"
  let flow = flowID
  task = Task {
   do {
    try await Task.sleep(nanoseconds: 800_000_000)
    let result = "Hello, it's a pleasure to meet you.\nI look forward to bringing this idea to life together."
    let outcome = try await TranslationDelivery.deliver(result, canAutoFill: false, isValid: { self.flowID == flow },
     show: { self.presentResult($0, language: "English") }, copy: { self.writeClipboard($0) },
     insert: { _ in fatalError("The offline preview must not insert into other apps") })
    self.status.stringValue = outcome.copied ? "翻译完成，译文已自动复制。" : "复制失败。"
    self.status.textColor = UI.accent; self.setBusy(false)
   } catch { if self.flowID == flow { self.setBusy(false) } }
  }
 }
 @objc private func reviewAppearance() { NSApp.appearance = NSAppearance(named: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? .darkAqua : .aqua) }
}
@MainActor final class PreviewDelegate: NSObject, NSApplicationDelegate {
 private let controller = AppDelegate()
 func applicationDidFinishLaunching(_ notification: Notification) { controller.startReview() }
}
@main struct PreviewMain {
 @MainActor static func main() {
  let app = NSApplication.shared; let delegate = PreviewDelegate(); app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
 }
}
