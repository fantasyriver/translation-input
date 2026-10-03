import AppKit

/// An offline review host for the production result window, with its own app identity.
@MainActor final class PreviewDelegate: NSObject, NSApplicationDelegate {
 private let result = ResultController()
 func applicationDidFinishLaunching(_ notification: Notification) {
  NSApp.setActivationPolicy(.regular); NSApp.appearance = NSAppearance(named: .aqua)
  let menu = NSMenu(); let item = NSMenuItem(); let submenu = NSMenu(); item.submenu = submenu; menu.addItem(item)
  let appearance = NSMenuItem(title: "切换深浅色", action: #selector(toggleAppearance), keyEquivalent: "d"); appearance.target = self; submenu.addItem(appearance)
  submenu.addItem(withTitle: "退出预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
  let editItem = NSMenuItem(); let edit = NSMenu(title: "编辑"); editItem.submenu = edit; menu.addItem(editItem)
  edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
  edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
  NSApp.mainMenu = menu
  result.show(text: "Hello, it's a pleasure to meet you.\nI look forward to bringing this idea to life together.\n\n让每一种语言，都成为表达的起点。")
 }
 @objc private func toggleAppearance() { NSApp.appearance = NSAppearance(named: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? .darkAqua : .aqua) }
}
@main struct PreviewMain {
 @MainActor static func main() {
  let app = NSApplication.shared; let delegate = PreviewDelegate(); app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
 }
}
