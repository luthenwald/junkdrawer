import AppKit

extension NSTextField {
   /// A label that never wraps; a label made with `labelWithString:` allows
   /// any number of lines.
   static func line(truncating: Bool = false) -> NSTextField {
      let label = NSTextField(labelWithString: "")
      label.maximumNumberOfLines = 1
      label.lineBreakMode = truncating ? .byTruncatingTail : .byClipping
      return label
   }

   /// The size the cell draws in. The intrinsic content size is a few
   /// points narrower, which clips the last character.
   var drawnSize: NSSize {
      cell?.cellSize ?? intrinsicContentSize
   }
}

extension NSAttributedString {
   /// The parts in a row, `gap` points apart.
   static func spaced(_ parts: [NSAttributedString], by gap: CGFloat) -> NSAttributedString {
      let text = NSMutableAttributedString()
      for part in parts {
         if text.length > 0 {
            text.addAttribute(.kern, value: gap, range: NSRange(location: text.length - 1, length: 1))
         }
         text.append(part)
      }
      return text
   }

   /// `string` at 12 points in `color`, in the system font unless `font`
   /// says otherwise, such as SF Mono or tabular digits.
   static func small(_ string: String, _ color: NSColor, font: NSFont = .systemFont(ofSize: 12)) -> NSAttributedString {
      NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
   }
}
