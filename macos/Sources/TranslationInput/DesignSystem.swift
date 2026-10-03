import AppKit

/// Shared native surfaces and controls. Colors resolve again when macOS appearance changes.
enum UI {
 static func applyAppearance() {
  switch UserDefaults.standard.string(forKey: "appearance") {
  case "light": NSApp.appearance = NSAppearance(named: .aqua)
  case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
  default: NSApp.appearance = nil
  }
 }
 static func adaptive(_ light: UInt32, _ dark: UInt32) -> NSColor {
  NSColor(name: nil) { appearance in
   let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
   return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
  }
 }
 static let background = adaptive(0xF5F5F0, 0x181D1B)
 static let surface = adaptive(0xFFFFFF, 0x232A27)
 static let field = adaptive(0xF5F7F4, 0x191F1C)
 static let ink = adaptive(0x202E28, 0xEBF1EC)
 static let muted = adaptive(0x5F6D64, 0xA5B4A9)
 static let line = adaptive(0xDFE5DF, 0x3A463E)
 static let accent = adaptive(0x146B4D, 0x9CDEB8)
 static let accentInk = adaptive(0xFFFFFF, 0x153D2A)
 static let tint = adaptive(0xE7F0E8, 0x2C4033)
 static let warning = adaptive(0xA34628, 0xF4B59E)
 @discardableResult static func label(_ text: String, in view: NSView, frame: NSRect, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = ink) -> NSTextField {
  let label = NSTextField(labelWithString: text)
  label.frame = frame; label.font = .systemFont(ofSize: size, weight: weight); label.textColor = color
  view.addSubview(label); return label
 }
 static func symbol(_ name: String, in view: NSView, frame: NSRect, color: NSColor = accent) {
  let image = NSImageView(frame: frame); image.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
  image.contentTintColor = color; image.imageScaling = .scaleProportionallyUpOrDown; view.addSubview(image)
 }
 static func field(_ field: NSTextField, in view: NSView, frame: NSRect) {
  let shell = Surface(frame: frame, color: self.field, radius: 9, bordered: true); view.addSubview(shell)
  field.frame = NSRect(x: 12, y: (frame.height - 20) / 2, width: frame.width - 24, height: 20)
  field.isBordered = false; field.drawsBackground = false; field.font = .systemFont(ofSize: 13)
  field.textColor = ink; field.focusRingType = .none; shell.focusTarget = field
  if let placeholder = field.placeholderString { field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [.foregroundColor: muted, .font: NSFont.systemFont(ofSize: 13)]) }
  shell.addSubview(field)
 }
 static func popup(_ popup: NSPopUpButton, in view: NSView, frame: NSRect) {
  let shell = Surface(frame: frame, color: field, radius: 9, bordered: true); view.addSubview(shell)
  shell.popupTarget = popup
  popup.frame = NSRect(x: 10, y: (frame.height - 26) / 2, width: frame.width - 18, height: 26)
  popup.isBordered = false; popup.font = .systemFont(ofSize: 13, weight: .medium); shell.addSubview(popup)
 }
 static func window(_ window: NSWindow) {
  window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden
  window.backgroundColor = background; window.isMovableByWindowBackground = true
 }
}

final class Surface: NSView {
 let color: NSColor
 let radius: CGFloat
 let bordered: Bool
 weak var focusTarget: NSTextField?
 weak var popupTarget: NSPopUpButton?
 override var mouseDownCanMoveWindow: Bool { focusTarget == nil && popupTarget == nil }
 override func mouseDown(with event: NSEvent) {
  if let focusTarget { window?.makeFirstResponder(focusTarget) }
  else if let popupTarget { popupTarget.performClick(nil) }
  else { super.mouseDown(with: event) }
 }
 override func resetCursorRects() {
  super.resetCursorRects(); if focusTarget != nil { addCursorRect(bounds, cursor: .iBeam) }
 }
 private var focusObservation: NSObjectProtocol?
 private var hasFocus = false
 override func viewDidMoveToWindow() {
  super.viewDidMoveToWindow()
  if let focusObservation { NotificationCenter.default.removeObserver(focusObservation) }
  guard let window else { focusObservation = nil; return }
  focusObservation = NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: window, queue: .main) { [weak self] _ in
   guard let self else { return }
   let focused = self.focusTarget?.currentEditor().map { self.window?.firstResponder === $0 && self.window?.isKeyWindow == true } ?? false
   if focused != self.hasFocus { self.hasFocus = focused; self.needsDisplay = true }
  }
 }
 deinit { if let focusObservation { NotificationCenter.default.removeObserver(focusObservation) } }
 init(frame: NSRect, color: NSColor = UI.surface, radius: CGFloat = 16, bordered: Bool = false) {
  self.color = color; self.radius = radius; self.bordered = bordered; super.init(frame: frame)
 }
 required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
 override func draw(_ dirtyRect: NSRect) {
  color.setFill(); NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
  if bordered { UI.line.setStroke(); let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius); path.lineWidth = 1; path.stroke() }
  if hasFocus {
   UI.accent.setStroke(); let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius); ring.lineWidth = 2; ring.stroke()
  }
 }
 override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}

/// NSButton retains native target/action, keyboard activation and accessibility semantics.
final class ActionButton: NSButton {
 var primary = false { didSet { needsDisplay = true } }
 var compact = false
 private var hovering = false
 private var tracking: NSTrackingArea?
 override var isEnabled: Bool { didSet { needsDisplay = true } }
 override var title: String { didSet { needsDisplay = true } }
 convenience init(_ title: String, primary: Bool = false, target: AnyObject?, action: Selector?) {
  self.init(frame: .zero); self.title = title; self.primary = primary; self.target = target; self.action = action
  setButtonType(.momentaryPushIn); isBordered = false; focusRingType = .exterior
 }
 override func updateTrackingAreas() {
  super.updateTrackingAreas(); if let tracking { removeTrackingArea(tracking) }
  tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
  addTrackingArea(tracking!)
 }
 override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
 override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }
 override func draw(_ dirtyRect: NSRect) {
  let background = primary && isEnabled ? UI.accent : UI.tint
  background.withAlphaComponent(isEnabled ? (isHighlighted ? 0.78 : hovering ? 0.88 : 1) : 1).setFill()
  NSBezierPath(roundedRect: bounds, xRadius: compact ? 8 : 11, yRadius: compact ? 8 : 11).fill()
  let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
  let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: compact ? 12 : 14, weight: .semibold), .foregroundColor: !isEnabled ? UI.muted : primary ? UI.accentInk : UI.accent, .paragraphStyle: paragraph])
  let height = text.size().height
  text.draw(in: NSRect(x: 8, y: (bounds.height - height) / 2, width: bounds.width - 16, height: height))
 }
 override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 11, yRadius: 11).fill() }
 override var focusRingMaskBounds: NSRect { bounds }
 override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
}
