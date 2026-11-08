import AppKit

/// The mode and the selection on the left, the keys and what they do on
/// the right.
final class Footer: NSView {
   static let height: CGFloat = 36
   private static let inset: CGFloat = 18

   private let left = NSTextField.line()
   private let right = NSTextField.line()

   init() {
      super.init(frame: .zero)
      [left, right].forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   /// `hints` pairs a key with what it does, such as ("⌘↵", "reveal in Finder").
   func show(mode: String, counter: String, hints: [(key: String, action: String)]) {
      left.attributedStringValue = Self.spaced([
         Self.run(mode, .secondary),
         Self.run(counter, .secondary, digits: true),
      ], by: 12)
      right.attributedStringValue = Self.spaced(hints.map { hint in
         let text = NSMutableAttributedString(attributedString: Self.run(hint.key, .text))
         text.append(Self.run(" " + hint.action, .secondary))
         return text
      }, by: 14)
      needsLayout = true
   }

   override func layout() {
      super.layout()
      let leftSize = left.drawnSize
      let rightSize = right.drawnSize
      let middle = bounds.height / 2
      right.frame = NSRect(x: bounds.width - Self.inset - rightSize.width, y: middle - rightSize.height / 2, width: rightSize.width, height: rightSize.height)
      left.frame = NSRect(x: Self.inset, y: middle - leftSize.height / 2, width: min(leftSize.width, right.frame.minX - Self.inset), height: leftSize.height)
   }

   private static func run(_ string: String, _ color: NSColor, digits: Bool = false) -> NSAttributedString {
      let font: NSFont = digits ? .monospacedDigitSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 12)
      return NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
   }

   /// The parts in a row, `gap` points apart.
   private static func spaced(_ parts: [NSAttributedString], by gap: CGFloat) -> NSAttributedString {
      let text = NSMutableAttributedString()
      for part in parts {
         if text.length > 0 {
            text.addAttribute(.kern, value: gap, range: NSRange(location: text.length - 1, length: 1))
         }
         text.append(part)
      }
      return text
   }
}
