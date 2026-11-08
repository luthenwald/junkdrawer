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
      left.attributedStringValue = .spaced([
         .small(mode, .secondary),
         .small(counter, .secondary, font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular)),
      ], by: 12)
      right.attributedStringValue = .spaced(hints.map { hint in
         let text = NSMutableAttributedString(attributedString: .small(hint.key, .text))
         text.append(.small(" " + hint.action, .secondary))
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
}
