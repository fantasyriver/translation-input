import AppKit
import ApplicationServices
import TranslationCore

@MainActor final class SettingsController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
 private let provider = NSPopUpButton(frame: .zero, pullsDown: false)
 private let appearance = NSPopUpButton(frame: .zero, pullsDown: false)
 private let api = NSPopUpButton(frame: .zero, pullsDown: false)
 private let endpoint = NSTextField()
 private let model = NSTextField()
 private let token = NSSecureTextField()
 private let providerNote = NSTextField(wrappingLabelWithString: "")
 private let recorder = ActionButton("", target: nil, action: nil)
 private let permissionState = NSTextField(labelWithString: "")
 private let status = NSTextField(wrappingLabelWithString: "")
 private lazy var draft = CredentialDraft(configuration: Preferences.llm.current) { Credentials.read(configuration: $0) ?? "" }
 private lazy var binding = ShortcutBinding(current: Preferences.shortcut, register: { [weak self] key in self?.saveShortcut?(key) ?? -1 }, persist: { Preferences.shortcut = $0 })
 private var monitor: Any?
 var openPanel: (() -> Void)?
 var shortcutError: (() -> String?)?
 var recordingChanged: ((Bool) -> Int32)?
 var saveShortcut: ((HotKey) -> Int32)?
 init() {
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 700), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
  window.title = "译入 · 设置"; window.isReleasedWhenClosed = false; UI.window(window)
  super.init(window: window); window.delegate = self
  let view = window.contentView!
  let mark = Surface(frame: NSRect(x: 28, y: 608, width: 48, height: 48), color: UI.accent, radius: 14); view.addSubview(mark)
  UI.symbol("character.bubble", in: mark, frame: NSRect(x: 11, y: 11, width: 26, height: 26), color: UI.accentInk)
  UI.label("让表达，自在发生。", in: view, frame: NSRect(x: 90, y: 632, width: 480, height: 30), size: 25, weight: .semibold)
  UI.label("译入  /  设置你的翻译方式", in: view, frame: NSRect(x: 90, y: 608, width: 450, height: 20), size: 12, color: UI.muted)
  appearance.addItems(withTitles: ["跟随系统", "浅色", "深色"])
  appearance.selectItem(at: ["system", "light", "dark"].firstIndex(of: UserDefaults.standard.string(forKey: "appearance") ?? "system") ?? 0)
  appearance.target = self; appearance.action = #selector(appearanceChanged); appearance.setAccessibilityLabel("外观")
  UI.label("外观", in: view, frame: NSRect(x: 536, y: 644, width: 136, height: 17), size: 11, color: UI.muted)
  UI.popup(appearance, in: view, frame: NSRect(x: 530, y: 606, width: 142, height: 32))
  let card = Surface(frame: NSRect(x: 24, y: 224, width: 652, height: 362), bordered: true); view.addSubview(card)
  UI.label("模型服务", in: view, frame: NSRect(x: 44, y: 543, width: 300, height: 25), size: 17, weight: .semibold)
  let reset = ActionButton("恢复预设", target: self, action: #selector(resetPreset)); reset.compact = true; reset.frame = NSRect(x: 552, y: 542, width: 104, height: 28); view.addSubview(reset)
  for value in LLMProvider.allCases { provider.addItem(withTitle: value.title) }
  provider.target = self; provider.action = #selector(providerChanged)
  UI.popup(provider, in: view, frame: NSRect(x: 44, y: 487, width: 612, height: 40))
  providerNote.frame = NSRect(x: 44, y: 453, width: 612, height: 27); providerNote.font = .systemFont(ofSize: 11); providerNote.textColor = UI.muted; view.addSubview(providerNote)
  UI.label("API Key", in: view, frame: NSRect(x: 44, y: 428, width: 120, height: 18), size: 12, weight: .medium)
  UI.symbol("lock", in: view, frame: NSRect(x: 531, y: 431, width: 12, height: 12), color: UI.muted)
  UI.label("保存在本机钥匙串", in: view, frame: NSRect(x: 549, y: 428, width: 108, height: 18), size: 11, color: UI.muted)
  token.placeholderString = "填写提供商的 API Key"; token.delegate = self
  UI.field(token, in: view, frame: NSRect(x: 44, y: 381, width: 612, height: 38))
  UI.label("API 地址", in: view, frame: NSRect(x: 44, y: 353, width: 160, height: 18), size: 12, weight: .medium)
  endpoint.placeholderString = "https://api.example.com/v1/chat/completions"; endpoint.delegate = self
  UI.field(endpoint, in: view, frame: NSRect(x: 44, y: 308, width: 612, height: 36))
  UI.label("模型", in: view, frame: NSRect(x: 44, y: 281, width: 180, height: 18), size: 12, weight: .medium)
  UI.label("接口协议", in: view, frame: NSRect(x: 350, y: 281, width: 180, height: 18), size: 12, weight: .medium)
  model.placeholderString = "模型 ID"; model.delegate = self
  UI.field(model, in: view, frame: NSRect(x: 44, y: 242, width: 290, height: 32))
  for value in LLMAPI.allCases { api.addItem(withTitle: value.title) }
  api.target = self; api.action = #selector(protocolChanged)
  UI.popup(api, in: view, frame: NSRect(x: 350, y: 242, width: 306, height: 32))
  let general = Surface(frame: NSRect(x: 24, y: 107, width: 652, height: 99), bordered: true); view.addSubview(general)
  UI.label("唤起快捷键", in: view, frame: NSRect(x: 44, y: 173, width: 210, height: 18), size: 12, weight: .medium)
  recorder.frame = NSRect(x: 44, y: 123, width: 235, height: 36); recorder.target = self; recorder.action = #selector(record); view.addSubview(recorder)
  recorder.setAccessibilityLabel("录制唤起快捷键"); recorder.toolTip = "点击录制，立即保存；Esc 取消"
  UI.label("自动回填", in: view, frame: NSRect(x: 319, y: 173, width: 200, height: 18), size: 12, weight: .medium)
  permissionState.frame = NSRect(x: 319, y: 128, width: 150, height: 22); permissionState.font = .systemFont(ofSize: 12); permissionState.textColor = UI.muted; view.addSubview(permissionState)
  let permission = ActionButton("管理权限…", target: self, action: #selector(permissionClick)); permission.frame = NSRect(x: 518, y: 123, width: 138, height: 36); view.addSubview(permission)
  UI.label("文字直接交给所选模型处理，API 费用由提供商计费。", in: view, frame: NSRect(x: 28, y: 79, width: 644, height: 17), size: 11, color: UI.muted)
  status.frame = NSRect(x: 28, y: 20, width: 340, height: 45); status.font = .systemFont(ofSize: 11); status.textColor = UI.muted; view.addSubview(status)
  let open = ActionButton("打开输入框", target: self, action: #selector(openInput)); open.frame = NSRect(x: 378, y: 24, width: 132, height: 40); view.addSubview(open)
  let save = ActionButton("保存配置", primary: true, target: self, action: #selector(save)); save.frame = NSRect(x: 522, y: 24, width: 150, height: 40); view.addSubview(save)
  endpoint.setAccessibilityLabel("API 地址"); endpoint.setAccessibilityHelp("完整的翻译接口 URL")
  model.setAccessibilityLabel("模型名"); token.setAccessibilityLabel("API Key"); provider.setAccessibilityLabel("模型提供商"); api.setAccessibilityLabel("接口协议")
  window.initialFirstResponder = token
  provider.nextKeyView = token; token.nextKeyView = endpoint; endpoint.nextKeyView = model; model.nextKeyView = api; api.nextKeyView = recorder
 }

 required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
 func show(shortcutFailure: String? = nil) {
  load(Preferences.llm.current)
  recorder.title = binding.current.label
  status.textColor = UI.muted
  status.stringValue = shortcutFailure ?? shortcutError?() ?? "选择提供商，填写 Key 即可开始。"
  refreshPermission()
  window?.center(); showWindow(nil); NSApp.activate(ignoringOtherApps: true)
 }
 @objc private func appearanceChanged() {
  UserDefaults.standard.set(["system", "light", "dark"][appearance.indexOfSelectedItem], forKey: "appearance")
  UI.applyAppearance()
 }
 private func load(_ configuration: LLMConfiguration) {
  draft = CredentialDraft(configuration: configuration) { Credentials.read(configuration: $0) ?? "" }
  provider.selectItem(at: LLMProvider.allCases.firstIndex(of: configuration.provider)!)
  api.selectItem(at: LLMAPI.allCases.firstIndex(of: configuration.api)!)
  endpoint.stringValue = configuration.endpoint; model.stringValue = configuration.model; token.stringValue = draft.apiKey
  providerNote.stringValue = configuration.provider.note
 }
 private func syncDraft() {
  draft.apiKey = token.stringValue
  var config = draft.configuration
  config.endpoint = endpoint.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
  config.model = model.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
  config.api = LLMAPI.allCases[api.indexOfSelectedItem]
  draft.update(configuration: config)
  token.stringValue = draft.apiKey
 }
 @objc private func providerChanged() {
  let value = LLMProvider.allCases[provider.indexOfSelectedItem]
  load(Preferences.llm.configuration(for: value))
  status.textColor = UI.muted
  status.stringValue = "已载入 \(value.title)，保存后启用。"
 }
 @objc private func resetPreset() {
  load(LLMProvider.allCases[provider.indexOfSelectedItem].preset)
  status.textColor = UI.muted
  status.stringValue = "预设已恢复，保存后生效。"
 }
 @objc private func protocolChanged() { syncDraft(); status.stringValue = "协议已调整，请检查地址和 Key 后保存。" }
 func controlTextDidBeginEditing(_ notification: Notification) { (notification.object as? NSTextField)?.superview?.needsDisplay = true }
 func controlTextDidEndEditing(_ notification: Notification) { (notification.object as? NSTextField)?.superview?.needsDisplay = true }
 func controlTextDidChange(_ notification: Notification) {
  syncDraft(); status.textColor = UI.muted; status.stringValue = "配置已修改，保存后生效。"
  if notification.object as? NSTextField === endpoint { status.stringValue = "地址已修改，请确认对应的 Key 后保存。" }
 }
 @objc private func openInput() { openPanel?() }
 @objc private func permissionClick() {
  status.textColor = UI.muted
  status.stringValue = AutoFillSettings.open() ? "在辅助功能中开启“译入”，下次唤起时生效。" : "请打开系统设置 → 隐私与安全性 → 辅助功能。"
 }
 @objc private func record() {
  stopRecording()
  guard (recordingChanged?(true) ?? -1) == 0 else { status.stringValue = shortcutError?() ?? "暂时无法录制快捷键，请重试。"; return }
  recorder.title = "请按组合键（Esc 取消）"
  monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
   guard let self else { return event }
   if event.keyCode == 53 { self.stopRecording(); return nil }
   guard let key = HotKey.from(event) else { self.status.stringValue = "快捷键需包含 ⌘、⌃ 或 ⌥。"; return nil }
   self.stopRecording()
   let result = self.binding.apply(key)
   self.recorder.title = self.binding.current.label
   self.status.stringValue = result == 0 ? "快捷键已保存：\(key.label)。" : (self.shortcutError?() ?? "快捷键注册失败（\(result)），原配置保留。")
   return nil
  }
 }
 private func stopRecording() {
  if let monitor {
   NSEvent.removeMonitor(monitor)
   if (recordingChanged?(false) ?? -1) != 0 { status.stringValue = "原快捷键恢复失败，请重新录制。" + (shortcutError?() ?? "") }
  }
  monitor = nil; recorder.title = binding.current.label
 }
 @objc private func save() {
  stopRecording(); syncDraft()
  let configuration = draft.configuration
  let credential = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
  do {
   _ = try configuration.validated(apiKey: credential)
   try Credentials.save(credential, configuration: configuration)
   Preferences.llm.save(configuration)
   token.stringValue = credential; draft.apiKey = credential
   status.textColor = UI.accent
   status.stringValue = "已保存：\(configuration.provider.title) · \(configuration.model)。" + (shortcutError?() ?? "")
  } catch { status.textColor = UI.warning; status.stringValue = error.localizedDescription }
 }
 private func refreshPermission() { permissionState.stringValue = AutoFillSettings.isEnabled ? "辅助功能已授权" : "需要辅助功能权限" }
 func windowDidBecomeKey(_ notification: Notification) { refreshPermission() }
 func windowDidResignKey(_ notification: Notification) { stopRecording() }
 func windowWillClose(_ notification: Notification) { stopRecording() }
}
