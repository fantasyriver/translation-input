import AppKit

final class ComposerTextView: NSTextView {
 var changed: (() -> Void)?
 override func didChangeText() { super.didChangeText(); needsDisplay = true; changed?() }
 override func draw(_ dirtyRect: NSRect) {
  super.draw(dirtyRect)
  if string.isEmpty && !hasMarkedText() {
   let text = NSAttributedString(string: "在这里，写下你想说的话…", attributes: [.font: NSFont.systemFont(ofSize: 19), .foregroundColor: UI.muted])
   text.draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 5), y: textContainerInset.height))
  }
 }
 override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
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
