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
