import AppKit

/// A selectable translation card embedded in the composer.
@MainActor final class TranslationResultView: NSView {
 private let text = ComposerTextView()
 private let heading = NSTextField(labelWithString: "译文")
 private let copy = ActionButton("复制译文", target: nil, action: nil)
 var onCopy: (() -> Void)?
 var onDismiss: (() -> Void)?
 var string: String { text.string }
 override init(frame: NSRect) {
  super.init(frame: frame)
  let surface = Surface(frame: bounds, bordered: true); surface.autoresizingMask = [.width, .height]; addSubview(surface)
  UI.symbol("checkmark.bubble", in: self, frame: NSRect(x: 18, y: 151, width: 18, height: 18))
  heading.frame = NSRect(x: 45, y: 148, width: 460, height: 22); heading.font = .systemFont(ofSize: 12, weight: .semibold); heading.textColor = UI.accent; addSubview(heading)
  copy.frame = NSRect(x: bounds.width - 136, y: 142, width: 118, height: 32); copy.compact = true; copy.target = self; copy.action = #selector(copyText); addSubview(copy)
  let scroll = NSScrollView(frame: NSRect(x: 13, y: 16, width: bounds.width - 26, height: 113))
  scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
  text.frame = scroll.bounds; text.isEditable = false; text.isRichText = false; text.font = .systemFont(ofSize: 17); text.textColor = UI.ink
  text.drawsBackground = false; text.textContainerInset = NSSize(width: 3, height: 5); text.isVerticallyResizable = true; text.isHorizontallyResizable = false; text.autoresizingMask = [.width]
  text.textContainer?.widthTracksTextView = true; text.textContainer?.containerSize = NSSize(width: scroll.bounds.width, height: CGFloat.greatestFiniteMagnitude)
  text.setAccessibilityLabel("翻译结果"); text.dismiss = { [weak self] in self?.onDismiss?() }; text.submit = { [weak self] in self?.onCopy?() }
  scroll.documentView = text; addSubview(scroll)
 }
 required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
 func show(text value: String, language: String) {
  let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 5
  text.textStorage?.setAttributedString(NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: UI.ink, .paragraphStyle: paragraph]))
  text.setSelectedRange(NSRange(location: 0, length: 0)); text.scrollRangeToVisible(NSRange(location: 0, length: 0))
  heading.stringValue = "译文 · " + language; heading.textColor = UI.accent
 }
 func markPrevious() { if !text.string.isEmpty { heading.stringValue = "上次译文"; heading.textColor = UI.muted } }
 @objc private func copyText() { onCopy?() }
}
