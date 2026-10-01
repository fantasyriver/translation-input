import AppKit
import ApplicationServices
import TranslationCore

@MainActor final class SettingsController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
 private let provider = NSPopUpButton(frame: .zero, pullsDown: false)
 private let api = NSPopUpButton(frame: .zero, pullsDown: false)
 private let endpoint = NSTextField()
 private let model = NSTextField()
 private let token = NSSecureTextField()
 private let providerNote = NSTextField(wrappingLabelWithString: "")
 private let recorder = NSButton(title: "", target: nil, action: nil)
 private let status = NSTextField(wrappingLabelWithString: "")
 private lazy var draft = CredentialDraft(configuration: Preferences.llm.current) { Credentials.read(configuration: $0) ?? "" }
 private lazy var binding = ShortcutBinding(current: Preferences.shortcut, register: { [weak self] key in self?.saveShortcut?(key) ?? -1 }, persist: { Preferences.shortcut = $0 })
 private var monitor: Any?
 var openPanel: (() -> Void)?
 var shortcutError: (() -> String?)?
 var recordingChanged: ((Bool) -> Int32)?
 var saveShortcut: ((HotKey) -> Int32)?
 init() {
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 650), styleMask: [.titled, .closable], backing: .buffered, defer: false)
  window.title = "译入 · 设置"; window.isReleasedWhenClosed = false
  super.init(window: window); window.delegate = self
  let view = window.contentView!
  func label(_ text: String, _ y: CGFloat) {
   let field = NSTextField(labelWithString: text); field.frame = NSRect(x: 24, y: y, width: 570, height: 20); view.addSubview(field)
  }
  label("模型提供商", 610)
  provider.frame = NSRect(x: 20, y: 572, width: 375, height: 30)
  for value in LLMProvider.allCases { provider.addItem(withTitle: value.title) }
  provider.target = self; provider.action = #selector(providerChanged); view.addSubview(provider)
  let reset = NSButton(title: "恢复此提供商预设", target: self, action: #selector(resetPreset)); reset.bezelStyle = .rounded; reset.frame = NSRect(x: 406, y: 572, width: 190, height: 30); view.addSubview(reset)
  providerNote.frame = NSRect(x: 24, y: 524, width: 570, height: 40); providerNote.font = .systemFont(ofSize: 12); providerNote.textColor = .secondaryLabelColor; view.addSubview(providerNote)
  label("API 地址（完整接口 URL）", 499)
  endpoint.frame = NSRect(x: 24, y: 464, width: 572, height: 28); endpoint.placeholderString = "https://api.example.com/v1/chat/completions"; endpoint.delegate = self; view.addSubview(endpoint)
  label("模型名", 432)
  model.frame = NSRect(x: 24, y: 397, width: 260, height: 28); model.placeholderString = "模型 ID"; model.delegate = self; view.addSubview(model)
  api.frame = NSRect(x: 297, y: 397, width: 302, height: 28)
  for value in LLMAPI.allCases { api.addItem(withTitle: value.title) }
  api.target = self; api.action = #selector(protocolChanged); view.addSubview(api)
  label("API Key（仅保存在本机系统钥匙串）", 363)
  token.frame = NSRect(x: 24, y: 328, width: 572, height: 28); token.placeholderString = "填写所选提供商的 API Key"; token.delegate = self; view.addSubview(token)
  label("唤起快捷键（录制后立即生效）", 292)
  recorder.frame = NSRect(x: 24, y: 254, width: 235, height: 32); recorder.bezelStyle = .rounded; recorder.target = self; recorder.action = #selector(record); view.addSubview(recorder)
  let permission = NSButton(title: "开启自动回填权限…", target: self, action: #selector(permissionClick)); permission.bezelStyle = .rounded; permission.frame = NSRect(x: 339, y: 254, width: 257, height: 32); view.addSubview(permission)
  let note = NSTextField(wrappingLabelWithString: "确认翻译后，文字直接发送至所选 API 地址，由提供商处理并计费。API Key 保存在本机钥匙串。自动回填需辅助功能权限，译文会保留在剪贴板。")
  note.frame = NSRect(x: 24, y: 160, width: 572, height: 76); note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabelColor; view.addSubview(note)
  status.frame = NSRect(x: 24, y: 68, width: 572, height: 80); status.font = .systemFont(ofSize: 12); view.addSubview(status)
  let open = NSButton(title: "打开输入框", target: self, action: #selector(openInput)); open.bezelStyle = .rounded; open.frame = NSRect(x: 24, y: 20, width: 130, height: 32); view.addSubview(open)
  let save = NSButton(title: "保存模型配置", target: self, action: #selector(save)); save.bezelStyle = .rounded; save.frame = NSRect(x: 450, y: 20, width: 145, height: 32); view.addSubview(save)
  endpoint.setAccessibilityLabel("API 地址"); model.setAccessibilityLabel("模型名"); token.setAccessibilityLabel("API Key"); provider.setAccessibilityLabel("模型提供商"); api.setAccessibilityLabel("接口协议")
 }
 required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
 func show(shortcutFailure: String? = nil) {
  load(Preferences.llm.current)
  recorder.title = binding.current.label
  status.stringValue = shortcutFailure ?? shortcutError?() ?? "选择提供商，填写 Key 后保存即可。快捷键独立生效。"
  window?.center(); showWindow(nil); NSApp.activate(ignoringOtherApps: true)
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
  status.stringValue = "已载入 \(value.title) 的配置。修改后请保存；切换会放弃未保存的修改。"
 }
 @objc private func resetPreset() {
  load(LLMProvider.allCases[provider.indexOfSelectedItem].preset)
  status.stringValue = "已恢复默认地址、模型与协议，保存后生效。相同地址的 Key 会保留。"
 }
 @objc private func protocolChanged() { syncDraft(); status.stringValue = "协议已调整，请检查地址和 Key 后保存。" }
 func controlTextDidChange(_ notification: Notification) {
  syncDraft()
  if notification.object as? NSTextField === endpoint { status.stringValue = "地址已修改，Key 已切换到对应地址；请检查后保存。" }
 }
 @objc private func openInput() { openPanel?() }
 @objc private func permissionClick() {
  let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
  _ = AXIsProcessTrustedWithOptions(options)
  status.stringValue = "请在系统设置 → 隐私与安全性 → 辅助功能中开启“译入”。开发版重建后可能需要重新授权。"
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
   self.status.stringValue = result == 0 ? "已生效并保存：\(key.label)。无需再点保存。" : (self.shortcutError?() ?? "快捷键注册失败（\(result)），原配置保留。")
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
   status.stringValue = "已保存：\(configuration.provider.title) · \(configuration.model)。" + (shortcutError?() ?? "")
  } catch { status.stringValue = error.localizedDescription }
 }
 func windowDidResignKey(_ notification: Notification) { stopRecording() }
 func windowWillClose(_ notification: Notification) { stopRecording() }
}
