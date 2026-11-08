import AppKit
import JunkdrawerCore

/// The selected entry under the list in the dictionary mode: the headword
/// in New York with its pronunciation, then each part of speech with its
/// numbered senses and examples. A taller entry shows the senses that fit
/// whole; ↵ opens all of it in Dictionary.
final class DefinitionPane: NSView {
   static let maxHeight: CGFloat = 236
   private static let insets = NSEdgeInsets(top: 16, left: 22, bottom: 18, right: 22)
   private static let indent: CGFloat = 20

   private let text = NSTextField(wrappingLabelWithString: "")

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      text.maximumNumberOfLines = 0
      text.lineBreakMode = .byWordWrapping
      text.cell?.truncatesLastVisibleLine = true
      addSubview(text)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   /// The headword and the first piece always show, the first cut at the
   /// last line that fits if it must be; later senses only when whole.
   func show(_ definition: Definition) {
      let pieces = Self.pieces(of: definition)
      let shown = NSMutableAttributedString()
      for (index, piece) in pieces.enumerated() {
         let next = NSMutableAttributedString(attributedString: shown)
         next.append(piece)
         if index > 1, fittingHeight(next) > Self.maxHeight { break }
         shown.setAttributedString(next)
      }
      text.attributedStringValue = shown
      needsLayout = true
   }

   /// The height for the panel's width, at most `maxHeight`.
   var height: CGFloat {
      min(Self.maxHeight, fittingHeight(text.attributedStringValue))
   }

   /// Measured with a copy of the label's cell, which pads the text as the
   /// label draws it.
   private func fittingHeight(_ string: NSAttributedString) -> CGFloat {
      guard let cell = text.cell?.copy() as? NSCell else { return 0 }
      cell.attributedStringValue = string
      let inner = LauncherPanel.width - Self.insets.left - Self.insets.right
      let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: inner, height: .greatestFiniteMagnitude))
      return (size.height + Self.insets.top + Self.insets.bottom).rounded(.up)
   }

   override func layout() {
      super.layout()
      text.frame = NSRect(
         x: Self.insets.left, y: Self.insets.top,
         width: bounds.width - Self.insets.left - Self.insets.right,
         height: bounds.height - Self.insets.top - Self.insets.bottom
      )
   }

   /// The headword line, then one piece per sense, the first sense of a
   /// part of speech carrying its label.
   private static func pieces(of definition: Definition) -> [NSAttributedString] {
      let text = NSMutableAttributedString(string: definition.headword, attributes: [
         .font: serif(22), .foregroundColor: NSColor.text,
      ])
      if let pronunciation = definition.pronunciation {
         text.kernLast(by: 12)
         text.append(NSAttributedString(string: "/\(pronunciation)/", attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondary,
         ]))
      }
      guard definition.isParsed else {
         return [text, line(definition.raw, font: .systemFont(ofSize: 14), color: .text, style: paragraph(before: 10))]
      }
      return [text] + definition.blocks.flatMap { block in
         block.senses.enumerated().map { number, sense in
            let piece = NSMutableAttributedString()
            if number == 0, let partOfSpeech = block.partOfSpeech {
               piece.append(line(partOfSpeech, font: italic(12), color: .secondary, style: paragraph(before: 10)))
            }
            // A name's text is one long sense, with nothing to number.
            let numbered = block.partOfSpeech != nil || block.senses.count > 1
            piece.append(line((numbered ? "\(number + 1).\t" : "") + sense.text, font: .systemFont(ofSize: 14), color: .text, style: paragraph(before: 6, hanging: numbered, lineHeight: 1.25)))
            if let example = sense.example {
               piece.append(line("▸ \(example)", font: .systemFont(ofSize: 13), color: .secondary, style: paragraph(before: 2, indented: true)))
            }
            return piece
         }
      }
   }

   private static func line(_ string: String, font: NSFont, color: NSColor, style: NSParagraphStyle) -> NSAttributedString {
      NSAttributedString(string: "\n" + string, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
   }

   /// Senses hang their number in the indent; examples sit at the indent.
   private static func paragraph(before: CGFloat, hanging: Bool = false, indented: Bool = false, lineHeight: CGFloat = 1) -> NSParagraphStyle {
      let style = NSMutableParagraphStyle()
      style.paragraphSpacingBefore = before
      style.lineHeightMultiple = lineHeight
      style.lineBreakMode = .byWordWrapping
      if hanging || indented {
         style.headIndent = indent
         style.firstLineHeadIndent = indented ? indent : 0
         style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
         style.defaultTabInterval = indent
      }
      return style
   }

   /// New York, the system serif.
   private static func serif(_ size: CGFloat) -> NSFont {
      NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? .systemFont(ofSize: size)
   }

   private static func italic(_ size: CGFloat) -> NSFont {
      NSFont(descriptor: NSFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(.italic), size: size) ?? .systemFont(ofSize: size)
   }
}
