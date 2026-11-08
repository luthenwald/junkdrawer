import AppKit
import JunkdrawerCore

/// The rows that show, at most `LauncherPanel.visibleRows`. The selection
/// decides which rows those are, so the list needs no scroll view.
final class ResultList: NSView {
   static let padding: CGFloat = 6
   static let rowHeight: CGFloat = 44

   private let rowViews = (0..<LauncherPanel.visibleRows).map { _ in RowView() }
   private let empty = NSTextField.line()
   private var shown = 0
   /// The stroke icon for bookmarks, tinted like secondary text.
   private static let link = NSImage(systemSymbolName: "link", accessibilityDescription: nil)?
      .withSymbolConfiguration(.init(pointSize: 15, weight: .light))

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      (rowViews + [empty]).forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   /// With the empty text in place of rows when there are none.
   var height: CGFloat {
      2 * Self.padding + Self.rowHeight * CGFloat(max(shown, 1))
   }

   func show(_ rows: ArraySlice<Row>, selected: Int, icons: [String: CGImage], empty text: String) {
      shown = rows.count
      for (position, view) in rowViews.enumerated() {
         let row = rows.dropFirst(position).first
         view.isHidden = row == nil
         if let row { view.show(row, selected: position == selected, icon: Self.icon(for: row.item, in: icons)) }
      }
      empty.attributedStringValue = NSAttributedString(
         string: text, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondary]
      )
      empty.isHidden = !rows.isEmpty
      needsLayout = true
   }

   /// The gray icon for apps, the link for bookmarks, nothing for commands.
   private static func icon(for item: Item, in icons: [String: CGImage]) -> NSImage? {
      switch item.kind {
      case .app: icons[item.id].map { NSImage(cgImage: $0, size: NSSize(width: 28, height: 28)) }
      case .bookmark: link
      case .latex, .unicode, .dictionary, .command: nil
      }
   }

   override func layout() {
      super.layout()
      let width = bounds.width - 2 * Self.padding
      for (position, view) in rowViews.enumerated() {
         view.frame = NSRect(x: Self.padding, y: Self.padding + Self.rowHeight * CGFloat(position), width: width, height: Self.rowHeight)
      }
      let size = empty.drawnSize
      empty.frame = NSRect(
         x: Self.padding + RowView.inset, y: Self.padding + (Self.rowHeight - size.height) / 2,
         width: width - 2 * RowView.inset, height: size.height
      )
   }
}

/// One row: the icon or glyph cell, the title with its matched characters
/// in a heavier weight followed by the subtitle, and the right label.
private final class RowView: NSView {
   static let inset: CGFloat = 12
   private static let cell: CGFloat = 28
   private static let glyphWidth: CGFloat = 44

   private let icon = NSImageView()
   private let glyph = NSTextField.line()
   private let label = NSTextField.line(truncating: true)
   private let trailing = NSTextField.line()
   private var isSelected = false

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      wantsLayer = true
      layer?.cornerRadius = 8
      layer?.cornerCurve = .continuous
      icon.contentTintColor = .secondary
      trailing.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
      trailing.textColor = .secondary
      [icon, glyph, label, trailing].forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   /// A template image, such as a symbol, keeps its size and takes the
   /// secondary tint; an app icon fills the cell.
   func show(_ row: Row, selected: Bool, icon image: NSImage?) {
      isSelected = selected
      needsDisplay = true
      icon.imageScaling = image?.isTemplate == true ? .scaleNone : .scaleProportionallyUpOrDown
      icon.image = image
      glyph.attributedStringValue = Self.glyph(row.item)
      glyph.isHidden = row.item.kind != .latex && row.item.kind != .unicode
      label.attributedStringValue = Self.title(row)
      trailing.stringValue = row.item.trailing
      needsLayout = true
   }

   override var wantsUpdateLayer: Bool { true }

   /// Runs again on appearance changes, which resolves the color anew.
   override func updateLayer() {
      layer?.backgroundColor = isSelected ? NSColor.row.cgColor : NSColor.clear.cgColor
   }

   override func viewDidChangeEffectiveAppearance() {
      needsDisplay = true
   }

   override func layout() {
      super.layout()
      let middle = bounds.height / 2
      icon.frame = NSRect(x: Self.inset, y: middle - Self.cell / 2, width: Self.cell, height: Self.cell)
      let glyphHeight = glyph.drawnSize.height
      // Wider than the cell, centred on it, so a wide glyph or an
      // abbreviation such as NNBSP is not clipped.
      glyph.frame = NSRect(x: icon.frame.midX - Self.glyphWidth / 2, y: middle - glyphHeight / 2, width: Self.glyphWidth, height: glyphHeight)
      let right = trailing.drawnSize
      trailing.frame = NSRect(x: bounds.width - Self.inset - right.width, y: middle - right.height / 2, width: right.width, height: right.height)
      let left = icon.frame.maxX + Self.inset
      let height = label.drawnSize.height
      label.frame = NSRect(x: left, y: middle - height / 2, width: max(0, trailing.frame.minX - Self.inset - left), height: height)
   }

   /// The symbol at 20 points in the text color; emoji keep their own
   /// colors. An invisible character shows its abbreviation, such as NBSP,
   /// small and gray.
   private static func glyph(_ item: Item) -> NSAttributedString {
      let shown = item.glyph ?? ""
      let isLabel = item.primary != .insert(shown) && shown.allSatisfy(\.isASCII)
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byClipping
      return NSAttributedString(string: shown, attributes: [
         .font: NSFont.systemFont(ofSize: isLabel ? 10 : 20),
         .foregroundColor: isLabel ? NSColor.secondary : NSColor.text,
         .paragraphStyle: paragraph,
      ])
   }

   /// The title at 14 points, in SF Mono for LaTeX commands, matched
   /// characters semibold, then the subtitle at 13 points in the secondary
   /// gray, 10 points after it.
   private static func title(_ row: Row) -> NSAttributedString {
      let matched = Set(row.matched)
      let mono = row.item.kind == .latex
      let regular = mono ? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) : NSFont.systemFont(ofSize: 14)
      let heavy = mono ? NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold) : NSFont.systemFont(ofSize: 14, weight: .semibold)
      let text = NSMutableAttributedString()
      for (offset, character) in row.item.title.enumerated() {
         text.append(NSAttributedString(string: String(character), attributes: [
            .font: matched.contains(offset) ? heavy : regular, .foregroundColor: NSColor.text,
         ]))
      }
      if !row.item.subtitle.isEmpty, text.length > 0 {
         text.kernLast(by: 10)
         text.append(NSAttributedString(string: row.item.subtitle, attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondary,
         ]))
      }
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineBreakMode = .byTruncatingTail
      text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
      return text
   }
}
