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

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      empty.attributedStringValue = NSAttributedString(
         string: "No matches",
         attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondary]
      )
      (rowViews + [empty]).forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   /// With "No matches" in place of rows when there are none.
   var height: CGFloat {
      2 * Self.padding + Self.rowHeight * CGFloat(max(shown, 1))
   }

   func show(_ rows: ArraySlice<Row>, selected: Int, icons: [String: CGImage]) {
      shown = rows.count
      for (position, view) in rowViews.enumerated() {
         let row = rows.dropFirst(position).first
         view.isHidden = row == nil
         if let row { view.show(row, selected: position == selected, icon: icons[row.item.id]) }
      }
      empty.isHidden = !rows.isEmpty
      needsLayout = true
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

/// One row: the icon cell, the title with its matched characters in a
/// heavier weight followed by the subtitle, and the right label.
private final class RowView: NSView {
   static let inset: CGFloat = 12
   private static let cell: CGFloat = 28

   private let icon = NSImageView()
   private let label = NSTextField.line(truncating: true)
   private let trailing = NSTextField.line()
   private var isSelected = false

   override var isFlipped: Bool { true }

   init() {
      super.init(frame: .zero)
      wantsLayer = true
      layer?.cornerRadius = 8
      layer?.cornerCurve = .continuous
      icon.imageScaling = .scaleProportionallyUpOrDown
      trailing.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
      trailing.textColor = .secondary
      [icon, label, trailing].forEach(addSubview)
   }

   required init?(coder: NSCoder) {
      fatalError("not used")
   }

   func show(_ row: Row, selected: Bool, icon image: CGImage?) {
      isSelected = selected
      needsDisplay = true
      icon.image = image.map { NSImage(cgImage: $0, size: NSSize(width: Self.cell, height: Self.cell)) }
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
      let right = trailing.drawnSize
      trailing.frame = NSRect(x: bounds.width - Self.inset - right.width, y: middle - right.height / 2, width: right.width, height: right.height)
      let left = icon.frame.maxX + Self.inset
      let height = label.drawnSize.height
      label.frame = NSRect(x: left, y: middle - height / 2, width: max(0, trailing.frame.minX - Self.inset - left), height: height)
   }

   /// The title at 14 points, matched characters semibold, then the
   /// subtitle at 13 points in the secondary gray, 10 points after it.
   private static func title(_ row: Row) -> NSAttributedString {
      let matched = Set(row.matched)
      let regular = NSFont.systemFont(ofSize: 14)
      let heavy = NSFont.systemFont(ofSize: 14, weight: .semibold)
      let text = NSMutableAttributedString()
      for (offset, character) in row.item.title.enumerated() {
         text.append(NSAttributedString(string: String(character), attributes: [
            .font: matched.contains(offset) ? heavy : regular, .foregroundColor: NSColor.text,
         ]))
      }
      if !row.item.subtitle.isEmpty, text.length > 0 {
         text.addAttribute(.kern, value: 10, range: NSRange(location: text.length - 1, length: 1))
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
