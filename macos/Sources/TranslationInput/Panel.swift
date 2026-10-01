import AppKit

final class ComposerTextView: NSTextView {
 var submit: (() -> Void)?
 var dismiss: (() -> Void)?
 override func keyDown(with event: NSEvent) {
  if !hasMarkedText() {
   if event.keyCode == 36 && event.modifierFlags.contains(.command) { submit?(); return }
   if event.keyCode == 53 { dismiss?(); return }
  }
  super.keyDown(with: event)
 }
}
final class InputPanel: NSPanel {
 override var canBecomeKey: Bool { true }
 override var canBecomeMain: Bool { false }
}
