import Foundation

public struct HotKey: Codable, Equatable {
 public var keyCode: UInt32
 public var modifiers: UInt32
 public var label: String
 public init(keyCode: UInt32, modifiers: UInt32, label: String) { self.keyCode = keyCode; self.modifiers = modifiers; self.label = label }
 // Carbon virtual Space key and optionKey modifier.
 public static let standard = HotKey(keyCode: 49, modifiers: 2048, label: "⌥ Space")
 public func conflicts(with shortcuts: [SystemShortcut]) -> Bool {
  shortcuts.contains { $0.enabled && $0.keyCode == keyCode && $0.modifiers == modifiers }
 }
}
public struct SystemShortcut {
 public let keyCode: UInt32
 public let modifiers: UInt32
 public let enabled: Bool
 public init(keyCode: UInt32, modifiers: UInt32, enabled: Bool) { self.keyCode = keyCode; self.modifiers = modifiers; self.enabled = enabled }
}
/// Shortcut changes are independent of network credentials. Only registered values
/// become the displayed/persisted selection; rejected candidates never replace it.
public final class ShortcutBinding {
 public private(set) var current: HotKey
 private let register: (HotKey) -> Int32
 private let persist: (HotKey) -> Void
 public init(current: HotKey, register: @escaping (HotKey) -> Int32, persist: @escaping (HotKey) -> Void) { self.current = current; self.register = register; self.persist = persist }
 @discardableResult public func apply(_ candidate: HotKey) -> Int32 {
  let result = register(candidate)
  guard result == 0 else { return result }
  persist(candidate); current = candidate; return 0
 }
}
