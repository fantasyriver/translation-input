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
 private var resumeDraftFromSettings = false
 private var lastResult = ""
 private var panel: InputPanel!
 private let input = ComposerTextView()
 private let language = NSPopUpButton(frame: .zero, pullsDown: false)
 private let submit = ActionButton("翻译 ↗", primary: true, target: nil, action: nil)
 private let status = NSTextField(wrappingLabelWithString: "")
 private let progress = NSProgressIndicator()
 private let statusIcon = NSImageView()
 private let composer = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 392))
 private let resultView = TranslationResultView(frame: NSRect(x: 24, y: 96, width: 672, height: 190))
 private let autoFill = ActionButton("开启自动回填…", target: nil, action: nil)
 private let count = NSTextField(labelWithString: "0 / 10,000")
 private let modelBadge = NSTextField(labelWithString: "")

 func applicationDidFinishLaunching(_ notification: Notification) {
  NSApp.setActivationPolicy(.accessory)
  configureMenu(); configurePanel()
  settings.openPanel = { [weak self] in
   guard let self else { return }
   self.openPanel(captureTarget: !self.resumeDraftFromSettings)
  }
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
  panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 392), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
  panel.title = "译入"; UI.window(panel); panel.level = .floating
  panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]; panel.isReleasedWhenClosed = false
  panel.hidesOnDeactivate = false; panel.delegate = self
  let root = panel.contentView!; root.addSubview(composer)
  let content = composer
  let mark = Surface(frame: NSRect(x: 24, y: 302, width: 40, height: 40), color: UI.accent, radius: 12); content.addSubview(mark)
  UI.symbol("character.bubble", in: mark, frame: NSRect(x: 9, y: 9, width: 22, height: 22), color: UI.accentInk)
  UI.label("译入", in: content, frame: NSRect(x: 76, y: 319, width: 150, height: 24), size: 20, weight: .semibold)
  UI.label("让表达，自在发生。", in: content, frame: NSRect(x: 76, y: 299, width: 240, height: 18), size: 11, color: UI.muted)
  modelBadge.frame = NSRect(x: 380, y: 315, width: 252, height: 18); modelBadge.font = .systemFont(ofSize: 11, weight: .medium); modelBadge.textColor = UI.muted; modelBadge.alignment = .right; modelBadge.lineBreakMode = .byTruncatingMiddle; content.addSubview(modelBadge)
  let gear = NSButton(image: NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "打开设置")!, target: self, action: #selector(showSettings))
  gear.isBordered = false; gear.contentTintColor = UI.muted; gear.frame = NSRect(x: 656, y: 308, width: 36, height: 32); gear.toolTip = "模型与快捷键设置"; content.addSubview(gear)
  let editor = Surface(frame: NSRect(x: 24, y: 96, width: 470, height: 190), bordered: true); content.addSubview(editor)
  UI.label("原文", in: content, frame: NSRect(x: 42, y: 254, width: 60, height: 18), size: 12, weight: .semibold)
  UI.label("自动识别语言", in: content, frame: NSRect(x: 89, y: 254, width: 180, height: 18), size: 11, color: UI.muted)
  let scroll = NSScrollView(frame: NSRect(x: 36, y: 128, width: 446, height: 116)); scroll.borderType = .noBorder; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
  input.frame = NSRect(x: 0, y: 0, width: 446, height: 116); input.isRichText = false; input.isAutomaticQuoteSubstitutionEnabled = false; input.isAutomaticDashSubstitutionEnabled = false
  input.font = .systemFont(ofSize: 19); input.textColor = UI.ink; input.insertionPointColor = UI.accent; input.drawsBackground = false
  let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5
  input.defaultParagraphStyle = paragraph; input.typingAttributes[.paragraphStyle] = paragraph
  input.textContainerInset = NSSize(width: 2, height: 6)
  input.isVerticallyResizable = true; input.isHorizontallyResizable = false; input.autoresizingMask = [.width]
  input.textContainer?.widthTracksTextView = true; input.textContainer?.containerSize = NSSize(width: 446, height: CGFloat.greatestFiniteMagnitude)
  input.submit = { [weak self] in self?.translate() }; input.dismiss = { [weak self] in self?.dismiss() }; input.changed = { [weak self] in self?.updateInputState(); self?.resultView.markPrevious() }
  input.setAccessibilityLabel("待翻译的原文"); input.setAccessibilityHelp("支持任意输入法。Command Return 翻译，Return 换行，Escape 关闭。")
  scroll.documentView = input; content.addSubview(scroll)
  count.frame = NSRect(x: 312, y: 106, width: 164, height: 16); count.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular); count.textColor = UI.muted; count.alignment = .right; content.addSubview(count)
  UI.label("目标语言", in: content, frame: NSRect(x: 516, y: 257, width: 180, height: 18), size: 12, weight: .medium, color: UI.muted)
  for value in TargetLanguage.all { language.addItem(withTitle: value.title); language.lastItem?.representedObject = value.code }
  language.target = self; language.action = #selector(languageChanged)
  UI.popup(language, in: content, frame: NSRect(x: 514, y: 205, width: 182, height: 42))
  language.setAccessibilityLabel("目标语言")
  if let index = TargetLanguage.all.firstIndex(where: { $0.code == Preferences.language }) { language.selectItem(at: index) }
  submit.frame = NSRect(x: 514, y: 145, width: 182, height: 46); submit.target = self; submit.action = #selector(translate); content.addSubview(submit)
  UI.label("⌘ ↵ 翻译   ·   Esc 关闭", in: content, frame: NSRect(x: 517, y: 119, width: 179, height: 17), size: 10, color: UI.muted)
  UI.label("↵ 换行", in: content, frame: NSRect(x: 42, y: 106, width: 160, height: 16), size: 10, color: UI.muted)
  resultView.isHidden = true; root.addSubview(resultView)
  resultView.onCopy = { [weak self] in self?.copyResult() }
  resultView.onDismiss = { [weak self] in self?.dismiss() }
  let separator = Surface(frame: NSRect(x: 24, y: 77, width: 672, height: 1), color: UI.line, radius: 0); root.addSubview(separator)
  statusIcon.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: nil); statusIcon.contentTintColor = UI.muted; statusIcon.frame = NSRect(x: 24, y: 43, width: 16, height: 16); root.addSubview(statusIcon)
  progress.style = .spinning; progress.controlSize = .small; progress.frame = NSRect(x: 25, y: 43, width: 16, height: 16); progress.isDisplayedWhenStopped = false; root.addSubview(progress)
  status.frame = NSRect(x: 48, y: 18, width: 430, height: 43); status.font = .systemFont(ofSize: 11); status.textColor = UI.muted; root.addSubview(status)
  autoFill.frame = NSRect(x: 498, y: 26, width: 198, height: 34); autoFill.compact = true; autoFill.target = self; autoFill.action = #selector(configureAutoFill); root.addSubview(autoFill)
  refreshAutoFill()
  updateInputState()
 }
 private func updateInputState() {
  let length = input.string.unicodeScalars.count
  count.stringValue = "\(length.formatted()) / 10,000"; count.textColor = length > 10000 ? UI.warning : UI.muted
  submit.isEnabled = busy || (!input.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && length <= 10000)
  input.needsDisplay = true
 }

 @objc private func languageChanged() { Preferences.language = language.selectedItem?.representedObject as? String ?? "en"; resultView.markPrevious() }
 @objc private func openFromMenu() { if !panel.isVisible { openPanel() } else { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) } }
 private func togglePanel() { if panel.isKeyWindow { dismiss() } else { openPanel() } }
 private func openPanel(captureTarget: Bool = true) {
  cancelWork()
  if captureTarget { target = InsertionTarget.capture() }
  resumeDraftFromSettings = false; flowID = UUID()
  updateInputState()
  modelBadge.stringValue = Preferences.llm.current.model
  modelBadge.toolTip = "\(Preferences.llm.current.provider.title) · \(Preferences.llm.current.model)"
  status.textColor = UI.muted
  refreshAutoFill()
  status.stringValue = AutoFillSettings.isEnabled && target?.permitsText == true ? "翻译后回填到 \(target?.app.localizedName ?? "原应用")，并复制译文。" : "翻译后自动复制译文，可直接粘贴使用。"
  let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main!
  let frame = screen.visibleFrame
  panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: min(frame.maxY - panel.frame.height, max(frame.minY, frame.midY - panel.frame.height / 2 + min(120, frame.height * 0.1)))))
  NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(input)
 }
 private func setBusy(_ value: Bool) {
  busy = value; submit.title = value ? "取消翻译" : "翻译 ↗"; input.isEditable = !value; language.isEnabled = !value
  autoFill.isEnabled = !value
  updateInputState()
  statusIcon.isHidden = value
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
  guard let endpoint = try? configuration.validated(apiKey: apiKey) else { showSettings(); return }
  if Preferences.consentEndpoint != configuration.credentialAccount {
   let alert = NSAlert(); alert.messageText = "允许发送文字进行翻译？"
   alert.informativeText = "确认后，你输入的文字将发送至 \(endpoint.host ?? "配置的模型服务")，使用模型 \(configuration.model)。API 费用由提供商按你的账户计费。原文和译文仅在本次运行期间保存在内存中。"
   alert.addButton(withTitle: "允许并翻译"); alert.addButton(withTitle: "取消")
   guard alert.runModal() == .alertFirstButtonReturn else { return }; Preferences.consentEndpoint = configuration.credentialAccount
  }
  let text = input.string; let code = Preferences.language; let ticket = session.begin(); let flow = flowID; let savedTarget = target
  resultView.markPrevious()
  let translatedLanguage = language.titleOfSelectedItem ?? code
  setBusy(true); status.textColor = UI.accent; status.stringValue = "正在用 \(configuration.model) 翻译…"
  task = Task { [weak self] in
   guard let self else { return }
   do {
    let result = try await self.client.translate(text: text, language: code, configuration: configuration, apiKey: apiKey)
    guard !Task.isCancelled, self.flowID == flow, self.session.consume(ticket) else { return }
    self.inserting = true
    let outcome = try await TranslationDelivery.deliver(result,
     canAutoFill: AutoFillSettings.isEnabled && savedTarget?.permitsText == true,
     isValid: { self.flowID == flow },
     show: { self.presentResult($0, language: translatedLanguage) },
     copy: { self.writeClipboard($0) },
     insert: { try await InsertionCoordinator.insert($0, into: savedTarget, isValid: { self.flowID == flow }) })
    guard self.flowID == flow, !Task.isCancelled else { return }
    self.inserting = false; self.setBusy(false); self.refreshAutoFill()
    self.status.textColor = outcome.copied ? UI.accent : UI.warning
    switch outcome.insertion {
    case .sent: self.status.stringValue = "已发送回填操作，译文已复制。"
    case .skipped: self.status.stringValue = outcome.copied ? "翻译完成，译文已自动复制。" : "翻译完成，复制失败，请选择下方译文手动复制。"
    case .failed: self.status.stringValue = outcome.copied ? "译文已复制，请在目标位置粘贴。" : "自动回填和复制未完成，请选择下方译文手动复制。"
    }

   } catch {
    guard self.flowID == flow, !Task.isCancelled else { return }
    self.session.cancel(); self.inserting = false; self.setBusy(false)
    self.status.textColor = UI.warning
    self.status.stringValue = (error as? URLError)?.code == .timedOut ? "翻译超时，原文已保留。" : error.localizedDescription
   }
  }
 }
 private func presentResult(_ text: String, language: String) {
  lastResult = text; resultView.show(text: text, language: language)
  if resultView.isHidden {
   let old = panel.frame
   composer.setFrameOrigin(NSPoint(x: 0, y: 204))
   var expanded = NSRect(x: old.minX, y: old.minY - 204, width: old.width, height: old.height + 204)
   if let screen = panel.screen { expanded.origin.y = max(screen.visibleFrame.minY, expanded.minY) }
   panel.setFrame(expanded, display: true)
   resultView.isHidden = false
  }
 }
 private func writeClipboard(_ text: String) -> Bool {
  NSPasteboard.general.clearContents(); return NSPasteboard.general.setString(text, forType: .string)
 }
 @objc private func copyResult() {
  guard !lastResult.isEmpty else { return }
  let copied = writeClipboard(lastResult)
  status.textColor = copied ? UI.accent : UI.warning
  status.stringValue = copied ? "译文已复制。" : "复制失败，请选择译文手动复制。"
 }
 private func refreshAutoFill() { autoFill.title = AutoFillSettings.isEnabled ? "自动回填已开启 · 设置…" : "开启自动回填…" }
 @objc private func configureAutoFill() {
  status.textColor = UI.muted
  status.stringValue = AutoFillSettings.open() ? "在辅助功能中开启“译入”，下次唤起时生效。" : "请打开系统设置 → 隐私与安全性 → 辅助功能。"
 }
 func windowDidBecomeKey(_ notification: Notification) { if notification.object as? NSWindow === panel { refreshAutoFill() } }
 @objc private func showSettings() {
  resumeDraftFromSettings = panel.isVisible
  cancelWork(); panel.orderOut(nil); settings.show()
 }
 @objc private func quit() { cancelWork(); NSApp.terminate(nil) }
 func windowWillClose(_ notification: Notification) { if notification.object as? NSWindow === panel { cancelWork() } }
 func windowDidResignKey(_ notification: Notification) {
  if notification.object as? NSWindow === panel, !inserting, busy { cancelWork(); status.stringValue = "已离开输入框，翻译已取消；原文保留。" }
 }
}
@main struct TranslationInputMain {
 @MainActor static func main() {
  let app = NSApplication.shared
  UI.applyAppearance()
  let delegate = AppDelegate()
  app.delegate = delegate
  withExtendedLifetime(delegate) { app.run() }
 }
}
