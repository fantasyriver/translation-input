import AppKit

/// Two translation directions beside the caret where the result is inserted.
enum MenuBarIcon {
 static func make() -> NSImage {
  let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
   NSColor.black.setStroke()
   let arrows = NSBezierPath()
   arrows.lineWidth = 1.6; arrows.lineCapStyle = .round; arrows.lineJoinStyle = .round
   arrows.move(to: NSPoint(x: 2, y: 12))
   arrows.line(to: NSPoint(x: 12, y: 12))
   arrows.move(to: NSPoint(x: 9, y: 15))
   arrows.line(to: NSPoint(x: 12, y: 12))
   arrows.line(to: NSPoint(x: 9, y: 9))
   arrows.move(to: NSPoint(x: 12, y: 5))
   arrows.line(to: NSPoint(x: 2, y: 5))
   arrows.move(to: NSPoint(x: 5, y: 8))
   arrows.line(to: NSPoint(x: 2, y: 5))
   arrows.line(to: NSPoint(x: 5, y: 2))
   arrows.stroke()

   let caret = NSBezierPath()
   caret.lineWidth = 1.4; caret.lineCapStyle = .round
   caret.move(to: NSPoint(x: 18, y: 3))
   caret.line(to: NSPoint(x: 18, y: 14))
   for y: CGFloat in [3, 14] {
    caret.move(to: NSPoint(x: 16, y: y))
    caret.line(to: NSPoint(x: 20, y: y))
   }
   caret.stroke()
   return true
  }
  image.isTemplate = true
  image.accessibilityDescription = "译入：翻译并输入"
  return image
 }
}
