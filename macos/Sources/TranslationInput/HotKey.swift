import AppKit
import Carbon
import TranslationCore

extension HotKey {
 static func from(_ event: NSEvent) -> HotKey? {
  let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
  guard !flags.intersection([.command, .control, .option]).isEmpty else { return nil }
  var mods: UInt32 = 0; var label = ""
  if flags.contains(.control) { mods |= UInt32(controlKey); label += "⌃" }
  if flags.contains(.option) { mods |= UInt32(optionKey); label += "⌥" }
  if flags.contains(.shift) { mods |= UInt32(shiftKey); label += "⇧" }
  if flags.contains(.command) { mods |= UInt32(cmdKey); label += "⌘" }
  let key = event.keyCode == UInt16(kVK_Space) ? "Space" : (event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)")
  return HotKey(keyCode: UInt32(event.keyCode), modifiers: mods, label: label + " " + key)
 }
}
final class HotKeyManager {
 var onPress: (() -> Void)?
 private var hotKey: EventHotKeyRef?
 private var handler: EventHandlerRef?
 private var current: HotKey?
 private var counter: UInt32 = 0
 private var handlerStatus: OSStatus = noErr
 private var recording = false
 private(set) var lastError: String?
 init() {
  var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
  handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
   guard let context else { return OSStatus(eventNotHandledErr) }
   let owner = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
   guard let event else { return OSStatus(eventNotHandledErr) }
   var id = EventHotKeyID()
   guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
         id.signature == 0x5452494E, id.id == owner.counter, !owner.recording else { return OSStatus(eventNotHandledErr) }
   owner.onPress?(); return noErr
  }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
 }
 func register(_ value: HotKey) -> OSStatus {
  lastError = nil
  guard handlerStatus == noErr else { lastError = "无法安装快捷键处理器（\(handlerStatus)）。"; return handlerStatus }
  var array: Unmanaged<CFArray>?
  let queryStatus = CopySymbolicHotKeys(&array)
  guard queryStatus == noErr, let rows = array?.takeRetainedValue() as? [[String: Any]] else {
   lastError = "暂时无法检查系统快捷键，请重试。"; return queryStatus == noErr ? OSStatus(-1) : queryStatus
  }
  let shortcuts = rows.compactMap { row -> SystemShortcut? in
   guard let code = row[kHISymbolicHotKeyCode as String] as? NSNumber,
         let modifiers = row[kHISymbolicHotKeyModifiers as String] as? NSNumber,
         let enabled = row[kHISymbolicHotKeyEnabled as String] as? Bool else { return nil }
   return SystemShortcut(keyCode: code.uint32Value, modifiers: modifiers.uint32Value, enabled: enabled)
  }
  guard !value.conflicts(with: shortcuts) else {
   lastError = "\(value.label) 已被系统快捷键占用。请换一个组合，或在系统设置 → 键盘 → 键盘快捷键中调整。"; return OSStatus(eventHotKeyExistsErr)
  }
  if let current, current.keyCode == value.keyCode, current.modifiers == value.modifiers, hotKey != nil { return noErr }
  let nextID = counter &+ 1; var newRef: EventHotKeyRef?
  let status = RegisterEventHotKey(value.keyCode, value.modifiers, EventHotKeyID(signature: 0x5452494E, id: nextID), GetApplicationEventTarget(), 0, &newRef)
  if status == noErr { if let hotKey { UnregisterEventHotKey(hotKey) }; hotKey = newRef; current = value; counter = nextID }
  else { lastError = "快捷键注册失败（\(status)），可能被其他应用占用；请换一个组合。" }
  return status
 }
 @discardableResult func setRecording(_ value: Bool) -> OSStatus {
  guard recording != value else { return noErr }
  if value {
   if let hotKey {
    let result = UnregisterEventHotKey(hotKey)
    guard result == noErr else { lastError = "无法暂停当前快捷键（\(result)），请重新打开设置。"; return result }
   }
   hotKey = nil; recording = true; return noErr
  }
  recording = false
  if let current { return register(current) }
  return noErr
 }
 deinit { if let hotKey { UnregisterEventHotKey(hotKey) }; if let handler { RemoveEventHandler(handler) } }
}
enum Preferences {
 static let llm = LLMPreferences()
 static var language: String { get { UserDefaults.standard.string(forKey: "language") ?? "en" } set { UserDefaults.standard.set(newValue, forKey: "language") } }
 static var consentEndpoint: String? { get { UserDefaults.standard.string(forKey: "llm.consentScope") } set { UserDefaults.standard.set(newValue, forKey: "llm.consentScope") } }
 static var shortcut: HotKey {
  get { guard let data = UserDefaults.standard.data(forKey: "shortcut"), let value = try? JSONDecoder().decode(HotKey.self, from: data) else { return .standard }; return value }
  set { if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: "shortcut") } }
 }
}
