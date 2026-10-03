import AppKit

@MainActor final class ResultController: NSWindowController {
 private let text = ComposerTextView()
 private let feedback = NSTextField(labelWithString: "选择文字，或复制整段译文。")
 init() {
  let panel = InputPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 378), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
  panel.title = "译入 · 翻译结果"; panel.level = .floating; panel.isReleasedWhenClosed = false
  panel.hidesOnDeactivate = false; UI.window(panel)
  super.init(window: panel)
  let view = panel.contentView!
  UI.symbol("checkmark.bubble", in: view, frame: NSRect(x: 26, y: 302, width: 27, height: 27))
  UI.label("翻译结果", in: view, frame: NSRect(x: 66, y: 302, width: 400, height: 29), size: 22, weight: .semibold)
  let surface = Surface(frame: NSRect(x: 24, y: 88, width: 552, height: 194), bordered: true); view.addSubview(surface)
  let scroll = NSScrollView(frame: NSRect(x: 36, y: 101, width: 528, height: 168)); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
  text.frame = scroll.bounds; text.isEditable = false; text.isRichText = false; text.font = .systemFont(ofSize: 17); text.textColor = UI.ink
  text.drawsBackground = false; text.textContainerInset = NSSize(width: 3, height: 5); text.isVerticallyResizable = true; text.isHorizontallyResizable = false; text.autoresizingMask = [.width]
  text.textContainer?.widthTracksTextView = true; text.textContainer?.containerSize = NSSize(width: 528, height: CGFloat.greatestFiniteMagnitude)
  text.setAccessibilityLabel("翻译结果"); text.dismiss = { [weak self] in self?.close() }; text.submit = { [weak self] in self?.copyText() }
  scroll.documentView = text; view.addSubview(scroll)
  feedback.frame = NSRect(x: 28, y: 35, width: 378, height: 20); feedback.font = .systemFont(ofSize: 11); feedback.textColor = UI.muted; view.addSubview(feedback)
  let copy = ActionButton("复制译文", primary: true, target: self, action: #selector(copyText)); copy.frame = NSRect(x: 428, y: 26, width: 148, height: 40); view.addSubview(copy)
 }
 required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
 func show(text value: String) {
  let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5
  text.textStorage?.setAttributedString(NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: UI.ink, .paragraphStyle: paragraph])); text.setSelectedRange(NSRange(location: 0, length: 0)); text.scrollRangeToVisible(NSRange(location: 0, length: 0))
  feedback.stringValue = "选择文字，或复制整段译文。"; feedback.textColor = UI.muted
  window?.center(); showWindow(nil); NSApp.activate(ignoringOtherApps: true); window?.makeFirstResponder(text)
 }
 @objc private func copyText() {
  NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text.string, forType: .string)
  feedback.stringValue = "译文已复制。"; feedback.textColor = UI.accent
 }
}
