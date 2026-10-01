import AppKit
import TranslationCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
 private var item: NSStatusItem!
 private let hotKey = HotKeyManager()
 private let settings = SettingsController()
 private let client = TranslationClient()
 private var session = TranslationSession()
 private var task: Task<Void, Never>?
 private var flowID = UUID()
 private var target: InsertionTarget?
 private var inserting = false
 private var busy = false
 private var clearOnNextOpen = false
 private var lastResult = ""
 private var panel: InputPanel!
 private let input = ComposerTextView()
 private let language = NSPopUpButton(frame: .zero, pullsDown: false)
 private let submit = NSButton(title: "确定", target: nil, action: nil)
 private let status = NSTextField(wrappingLabelWithString: "")
 private let progress = NSProgressIndicator()
 private let copy = NSButton(title: "查看译文…", target: nil, action: nil)

 func applicationDidFinishLaunching(_ notification: Notification) {
  NSApp.setActivationPolicy(.accessory)
  configureMenu(); configurePanel()
  settings.openPanel = { [weak self] in self?.openPanel() }
  hotKey.onPress = { [weak self] in self?.togglePanel() }
  settings.saveShortcut = { [weak self] key in self?.hotKey.register(key) ?? -1 }
  settings.shortcutError = { [weak self] in self?.hotKey.lastError }
  settings.recordingChanged = { [weak self] in self?.hotKey.setRecording($0) ?? -1 }
  let result = hotKey.register(Preferences.shortcut)
  if result != 0 { settings.show(shortcutFailure: hotKey.lastError ?? "快捷键注册失败（\(result)），请重新录制。") }
  else if !Preferences.llm.current.allowsEmptyKey && Credentials.read(configuration: Preferences.llm.current) == nil { settings.show() }
 }
 private func configureMenu() {
  let mainMenu = NSMenu(); let appMenu = NSMenu(); let appItem = NSMenuItem(); appItem.submenu = appMenu; mainMenu.addItem(appItem)
  let quitItem = NSMenuItem(title: "退出译入", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quitItem.target = NSApp; appMenu.addItem(quitItem)
  let edit = NSMenu(title: "编辑"); let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); editItem.submenu = edit; mainMenu.addItem(editItem)
  for (title, action, key) in [("撤销", Selector(("undo:")), "z"), ("剪切", #selector(NSText.cut(_:)), "x"), ("复制", #selector(NSText.copy(_:)), "c"), ("粘贴", #selector(NSText.paste(_:)), "v"), ("全选", #selector(NSText.selectAll(_:)), "a")] { edit.addItem(withTitle: title, action: action, keyEquivalent: key) }
  NSApp.mainMenu = mainMenu
  item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  item.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "译入")
  let menu = NSMenu()
  func entry(_ title: String, _ action: Selector, _ key: String = "") { let row = NSMenuItem(title: title, action: action, keyEquivalent: key); row.target = self; menu.addItem(row) }
  entry("打开翻译输入框", #selector(openFromMenu)); entry("复制上次译文", #selector(copyResult)); menu.addItem(.separator())
  entry("设置…", #selector(showSettings), ","); entry("退出译入", #selector(quit), "q"); item.menu = menu
 }
 private func configurePanel() {
  panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 320), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
  panel.title = "译入"; panel.titlebarAppearsTransparent = true; panel.level = .floating
  panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]; panel.isReleasedWhenClosed = false
  panel.hidesOnDeactivate = false; panel.delegate = self
  let content = panel.contentView!
  let heading = NSTextField(labelWithString: "译入"); heading.font = .systemFont(ofSize: 18, weight: .semibold); heading.frame = NSRect(x: 24, y: 267, width: 200, height: 24); content.addSubview(heading)
  let scroll = NSScrollView(frame: NSRect(x: 24, y: 128, width: 420, height: 128)); scroll.borderType = .bezelBorder; scroll.hasVerticalScroller = true
  input.frame = NSRect(x: 0, y: 0, width: 418, height: 128); input.isRichText = false; input.isAutomaticQuoteSubstitutionEnabled = false; input.isAutomaticDashSubstitutionEnabled = false
  input.font = .systemFont(ofSize: 16); input.textContainerInset = NSSize(width: 10, height: 10)
  input.isVerticallyResizable = true; input.isHorizontallyResizable = false; input.autoresizingMask = [.width]
  input.textContainer?.widthTracksTextView = true; input.textContainer?.containerSize = NSSize(width: 418, height: CGFloat.greatestFiniteMagnitude)
  input.submit = { [weak self] in self?.translate() }; input.dismiss = { [weak self] in self?.dismiss() }
  scroll.documentView = input; content.addSubview(scroll)
  let targetLabel = NSTextField(labelWithString: "翻译为"); targetLabel.frame = NSRect(x: 462, y: 230, width: 150, height: 20); targetLabel.textColor = .secondaryLabelColor; content.addSubview(targetLabel)
  language.frame = NSRect(x: 458, y: 192, width: 160, height: 30)
  for value in TargetLanguage.all { language.addItem(withTitle: value.title); language.lastItem?.representedObject = value.code }
  language.target = self; language.action = #selector(languageChanged); content.addSubview(language)
  if let index = TargetLanguage.all.firstIndex(where: { $0.code == Preferences.language }) { language.selectItem(at: index) }
  submit.frame = NSRect(x: 458, y: 138, width: 160, height: 38); submit.bezelStyle = .rounded; submit.target = self; submit.action = #selector(translate); content.addSubview(submit)
  let hint = NSTextField(labelWithString: "⌘ Enter 确定 · Enter 换行 · Esc 关闭")
  hint.frame = NSRect(x: 24, y: 98, width: 450, height: 20); hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor; content.addSubview(hint)
  progress.style = .spinning; progress.controlSize = .small; progress.frame = NSRect(x: 24, y: 58, width: 16, height: 16); progress.isDisplayedWhenStopped = false; content.addSubview(progress)
  status.frame = NSRect(x: 48, y: 22, width: 560, height: 59); status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor; content.addSubview(status)
  copy.frame = NSRect(x: 458, y: 98, width: 160, height: 30); copy.bezelStyle = .rounded; copy.target = self; copy.action = #selector(showResult); copy.isHidden = true; content.addSubview(copy)
 }
 @objc private func languageChanged() { Preferences.language = language.selectedItem?.representedObject as? String ?? "en" }
 @objc private func openFromMenu() { if !panel.isVisible { openPanel() } else { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) } }
 private func togglePanel() { if panel.isKeyWindow { dismiss() } else { openPanel() } }
 private func openPanel() {
  cancelWork(); target = InsertionTarget.capture(); flowID = UUID()
  if clearOnNextOpen { input.string = ""; clearOnNextOpen = false }
  status.stringValue = target.map { "将回填到 \($0.app.localizedName ?? "原应用")。粘贴后译文保留在剪贴板。" } ?? "输入文字并选择目标语言；未确认目标时提供复制。"
  copy.isHidden = lastResult.isEmpty
  let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main!
  let frame = screen.visibleFrame
  panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2 + min(120, frame.height * 0.1)))
  NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(input)
 }
 private func setBusy(_ value: Bool) {
  busy = value; submit.title = value ? "取消" : "确定"; input.isEditable = !value; language.isEnabled = !value
  if value { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
 }
 private func cancelWork() { flowID = UUID(); task?.cancel(); task = nil; session.cancel(); inserting = false; setBusy(false) }
 private func dismiss() { cancelWork(); panel.orderOut(nil) }
 @objc private func translate() {
  if busy { cancelWork(); status.stringValue = "已取消，原文已保留。"; return }
  guard !input.hasMarkedText() else { status.stringValue = "请先确认输入法候选文字。"; return }
  guard !input.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, input.string.unicodeScalars.count <= 10000 else { status.stringValue = "请输入 1–10,000 个字符。"; return }
  let configuration = Preferences.llm.current
  let apiKey = Credentials.read(configuration: configuration) ?? ""
  guard let endpoint = try? configuration.validated(apiKey: apiKey) else { settings.show(); return }
  if Preferences.consentEndpoint != configuration.credentialAccount {
   let alert = NSAlert(); alert.messageText = "允许发送文字进行翻译？"
   alert.informativeText = "确认后，你输入的文字将发送至 \(endpoint.host ?? "配置的模型服务")，使用模型 \(configuration.model)。API 费用由提供商按你的账户计费。原文和译文仅在本次运行期间保存在内存中。"
   alert.addButton(withTitle: "允许并翻译"); alert.addButton(withTitle: "取消")
   guard alert.runModal() == .alertFirstButtonReturn else { return }; Preferences.consentEndpoint = configuration.credentialAccount
  }
  let text = input.string; let code = Preferences.language; let ticket = session.begin(); let flow = flowID; let savedTarget = target
  setBusy(true); status.stringValue = "正在翻译… 可点击取消。"
  task = Task { [weak self] in
   guard let self else { return }
   do {
    let result = try await self.client.translate(text: text, language: code, configuration: configuration, apiKey: apiKey)
    guard !Task.isCancelled, self.flowID == flow, self.session.consume(ticket) else { return }
    self.lastResult = result; self.copy.isHidden = false
    self.inserting = true; self.panel.orderOut(nil)
    do {
     try await InsertionCoordinator.insert(result, into: savedTarget, isValid: { self.flowID == flow })
     guard self.flowID == flow else { return }
     self.clearOnNextOpen = true; self.status.stringValue = "已发出粘贴操作，译文保留在剪贴板。"
    } catch {
     guard self.flowID == flow, !Task.isCancelled else { return }
     self.status.stringValue = error.localizedDescription
     self.panel.orderFrontRegardless() // Do not steal focus if the user is working elsewhere.
    }
    self.inserting = false; self.setBusy(false)
   } catch {
    guard self.flowID == flow, !Task.isCancelled else { return }
    self.session.cancel(); self.setBusy(false)
    self.status.stringValue = (error as? URLError)?.code == .timedOut ? "翻译超时，原文已保留。" : error.localizedDescription
   }
  }
 }
 @objc private func copyResult() {
  guard !lastResult.isEmpty else { NSSound.beep(); return }
  NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastResult, forType: .string)
  status.stringValue = "译文已复制。"
 }
 @objc private func showResult() {
  guard !lastResult.isEmpty else { return }
  let alert = NSAlert(); alert.messageText = "翻译结果"; alert.informativeText = "原文仍保留在输入框中。"
  let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 430, height: 190)); scroll.hasVerticalScroller = true
  let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isRichText = false; text.string = lastResult; text.font = .systemFont(ofSize: 14); text.autoresizingMask = [.width]; text.isVerticallyResizable = true; scroll.documentView = text
  alert.accessoryView = scroll; alert.addButton(withTitle: "复制译文"); alert.addButton(withTitle: "关闭")
  if alert.runModal() == .alertFirstButtonReturn { copyResult() }
 }
 @objc private func showSettings() { cancelWork(); settings.show() }
 @objc private func quit() { cancelWork(); NSApp.terminate(nil) }
 func windowWillClose(_ notification: Notification) { if notification.object as? NSWindow === panel { cancelWork() } }
 func windowDidResignKey(_ notification: Notification) {
  if notification.object as? NSWindow === panel, !inserting, busy { cancelWork(); status.stringValue = "已离开输入框，翻译已取消；原文保留。" }
 }
}
@main struct TranslationInputMain {
 @MainActor static func main() {
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
 }
}
