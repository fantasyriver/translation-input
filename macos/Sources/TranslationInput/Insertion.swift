import AppKit
import ApplicationServices

struct InsertionTarget {
 let app: NSRunningApplication
 let element: AXUIElement?
 let window: AXUIElement?
 let selection: CFTypeRef?
 let permitsText: Bool
 static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }; return value
 }
 static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
  guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }; return (value as! AXUIElement)
 }
 static func capture() -> InsertionTarget? {
  guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
  guard AXIsProcessTrusted() else { return InsertionTarget(app: app, element: nil, window: nil, selection: nil, permitsText: false) }
  let application = AXUIElementCreateApplication(app.processIdentifier)
  AXUIElementSetMessagingTimeout(application, 0.25)
  let element = elementAttribute(application, kAXFocusedUIElementAttribute)
  let window = elementAttribute(application, kAXFocusedWindowAttribute)
  let role = element.flatMap { attribute($0, kAXRoleAttribute) as? String }
  let subrole = element.flatMap { attribute($0, kAXSubroleAttribute) as? String }
  let editable = element.flatMap { attribute($0, "AXEditable") as? Bool } ?? false
  let permits = subrole != kAXSecureTextFieldSubrole && ([kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role ?? "") || editable)
  return InsertionTarget(app: app, element: element, window: window, selection: element.flatMap { attribute($0, kAXSelectedTextRangeAttribute) }, permitsText: permits)
 }
}
enum InsertionFailure: LocalizedError {
 case permission, noTarget, focusChanged, canceled
 var errorDescription: String? {
  switch self {
  case .permission: return "自动回填需要辅助功能权限。译文已保留，可复制粘贴。"
  case .noTarget: return "无法确认原输入位置，译文已保留，请手动复制。"
  case .focusChanged: return "原窗口或输入位置已改变，已停止自动回填。"
  case .canceled: return "已取消回填。"
  }
 }
}
@MainActor enum InsertionCoordinator {
 static func insert(_ text: String, into target: InsertionTarget?, isValid: () -> Bool) async throws {
  guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { throw InsertionFailure.permission }
  guard let target, target.permitsText, let element = target.element, let window = target.window, !target.app.isTerminated else { throw InsertionFailure.noTarget }
  let ownPID = ProcessInfo.processInfo.processIdentifier
  let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
  guard foreground == ownPID || foreground == target.app.processIdentifier else { throw InsertionFailure.focusChanged }
  guard isValid(), !Task.isCancelled else { throw InsertionFailure.canceled }
  guard target.app.activate(options: []) else { throw InsertionFailure.focusChanged }
  let application = AXUIElementCreateApplication(target.app.processIdentifier)
  AXUIElementSetMessagingTimeout(application, 0.25)
  var ready = false
  for _ in 0..<12 {
   try Task.checkCancellation(); guard isValid() else { throw InsertionFailure.canceled }
   if target.app.isActive,
      let currentWindow = InsertionTarget.elementAttribute(application, kAXFocusedWindowAttribute), CFEqual(currentWindow, window),
      let focused = InsertionTarget.elementAttribute(application, kAXFocusedUIElementAttribute), CFEqual(focused, element) { ready = true; break }
   try await Task.sleep(nanoseconds: 50_000_000)
  }
  guard ready, !target.app.isTerminated, isValid() else { throw InsertionFailure.focusChanged }
  if let selection = target.selection {
   guard let current = InsertionTarget.attribute(element, kAXSelectedTextRangeAttribute), CFEqual(selection, current) else { throw InsertionFailure.focusChanged }
  }
  guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true), let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { throw InsertionFailure.noTarget }
  // No universal paste-completion acknowledgement exists. Keep the translation in the
  // clipboard instead of restoring old data on a timer and racing the target app.
  guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier, isValid(), !Task.isCancelled else { throw InsertionFailure.focusChanged }
  let pasteboard = NSPasteboard.general; pasteboard.clearContents()
  guard pasteboard.setString(text, forType: .string) else { throw InsertionFailure.noTarget }
  // Recheck after all potentially slow AX calls, and target the saved process so
  // a late app switch cannot route the paste into a different application.
  guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.app.processIdentifier,
        !target.app.isTerminated, isValid(), !Task.isCancelled else { throw InsertionFailure.focusChanged }
  down.flags = .maskCommand; up.flags = .maskCommand
  down.postToPid(target.app.processIdentifier); up.postToPid(target.app.processIdentifier)
 }
}
